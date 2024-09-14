#[macro_use] extern crate rocket;

use mongodb::{Client, options::ClientOptions, bson::oid::ObjectId};
use mongodb::bson::{doc, Document as BsconDoc, DateTime};
use rocket::futures::TryStreamExt;
use rocket::serde::{json::Json, Deserialize, Serialize};
use rocket::http::Header;
use rocket::{State, Request, Response};
use rocket::fairing::{Fairing, Info, Kind};
use uuid::Uuid;
use rocket::data::ToByteUnit;
use rocket::tokio::fs::File;
use rocket::fs::{NamedFile};
use std::fs;
use std::path::{Path};
use std::sync::Arc;
use rocket::response::status::Custom;
use rocket::http::Status;
use rocket::request::{FromRequest, Outcome};


#[derive(Debug, Serialize, Deserialize)]
struct Document {
    #[serde(rename = "_id", skip_serializing_if = "Option::is_none")]
    id: Option<ObjectId>,
    title: String,
    content: String,
    tags: Vec<String>,
    summary: Option<String>,
    rating: Option<i32>,
}

// CORS Fairing to add headers to all responses
pub struct CORS;

#[rocket::async_trait]
impl Fairing for CORS {
    fn info(&self) -> Info {
        Info {
            name: "Add CORS headers to responses",
            kind: Kind::Response,
        }
    }

    async fn on_response<'r>(&self, _req: &'r Request<'_>, res: &mut Response<'r>) {
        res.set_header(Header::new("Access-Control-Allow-Origin", "*"));
        res.set_header(Header::new("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS"));
        res.set_header(Header::new("Access-Control-Allow-Headers", "Content-Type"));
        res.set_header(Header::new("Access-Control-Allow-Headers", "Content-Type, x-api-key"));
    }
}

// Route to get all documents
#[get("/documents")]
async fn get_documents(_api_key: ApiKey, client: &State<Client>) -> Json<Vec<Document>> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let cursor = collection.find(None, None).await.expect("Failed to find documents");
    let documents: Vec<Document> = cursor.try_collect().await.expect("Error collecting documents");

    Json(documents)
}

// Route to get a document by ID
#[get("/documents/<id>")]
async fn get_document_by_id(_api_key: ApiKey, client: &State<Client>, id: &str) -> Option<Json<Document>> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let object_id = ObjectId::parse_str(id).ok()?;
    let filter = doc! { "_id": object_id };
    let document = collection.find_one(filter, None).await.ok()??;

    Some(Json(document))
}

// Route to handle search
#[get("/search?<term>")]
async fn search_documents(_api_key: ApiKey, client: &State<Client>, term: String) -> Json<Vec<Document>> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let filter = doc! {
        "$or": [
            { "title": { "$regex": term.clone(), "$options": "i" } },
            { "content": { "$regex": term.clone(), "$options": "i" } },
            { "tags": { "$regex": term.clone(), "$options": "i" } }
        ]
    };
    let cursor = collection.find(filter, None).await.expect("Failed to search documents");
    let documents: Vec<Document> = cursor.try_collect().await.expect("Error collecting search results");

    Json(documents)
}

// Route to create a new document
#[post("/documents", data = "<document>")]
async fn create_document(_api_key: ApiKey, client: &State<Client>, document: Json<Document>) -> Json<ObjectId> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let new_doc = Document {
        id: None,
        title: document.title.clone(),
        content: document.content.clone(),
        tags: document.tags.clone(),
        summary: document.summary.clone(),
        rating: document.rating,
    };

    let insert_result = collection.insert_one(new_doc, None).await.expect("Failed to insert document");
    Json(insert_result.inserted_id.as_object_id().unwrap())
}

#[post("/upload_pdf/<document_id>", data = "<file>")]
async fn upload_pdf(_api_key: ApiKey, document_id: String, file: rocket::data::Data<'_>) -> Result<String, Custom<String>> {
    // Generate a unique filename using UUID
    let pdf_id = Uuid::new_v4().to_string();
    let pdf_directory = "pdfs/";
    let storage_filename = format!("{}.pdf", pdf_id);
    let pdf_path = format!("{}{}", pdf_directory, storage_filename);

    // Ensure the PDFs directory exists
    if let Err(e) = fs::create_dir_all(pdf_directory) {
        return Err(Custom(rocket::http::Status::InternalServerError, format!("Failed to create directory: {}", e)));
    }

    // Write the PDF file to the server
    let mut pdf_file = File::create(&pdf_path).await.map_err(|e| {
        Custom(rocket::http::Status::InternalServerError, format!("Failed to save PDF: {}", e))
    })?;
    file.open(10.mebibytes()).stream_to(&mut pdf_file).await.map_err(|e| {
        Custom(rocket::http::Status::InternalServerError, format!("Failed to stream PDF: {}", e))
    })?;

    // Clone document_id to avoid moving it
    let document_id_cloned = document_id.clone();

    // Connect to MongoDB and store the PDF metadata in the "pdfs" collection
    let client_options = ClientOptions::parse("mongodb://localhost:27017").await.unwrap();
    let client = Client::with_options(client_options).unwrap();
    let collection = client.database("document_manager").collection("pdfs");

    // Insert the metadata for the uploaded PDF
    collection.insert_one(doc! {
        "_id": pdf_id,
        "document_id": document_id,
        "storage_filename": storage_filename,
        "uploaded_at": DateTime::now() // MongoDB-compatible timestamp
    }, None).await.map_err(|e| {
        Custom(rocket::http::Status::InternalServerError, format!("Failed to insert into MongoDB: {}", e))
    })?;

    Ok(format!("Uploaded PDF for document ID {}", document_id_cloned))
}

#[get("/pdf/<document_id>")]
async fn get_pdf(_api_key: ApiKey, document_id: String) -> Option<NamedFile> {
    // Connect to MongoDB to retrieve the PDF metadata
    let client_options = ClientOptions::parse("mongodb://localhost:27017").await.unwrap();
    let client = Client::with_options(client_options).unwrap();
    let collection = client.database("document_manager").collection("pdfs");

    // Find the PDF entry by document_id
    let pdf_entry: Option<BsconDoc> = collection.find_one(doc! { "document_id": &document_id }, None).await.unwrap();
    let storage_filename = pdf_entry?.get_str("storage_filename").ok()?.to_string();

    // Serve the PDF file from the filesystem
    let pdf_path = Path::new("pdfs/").join(storage_filename);
    NamedFile::open(pdf_path).await.ok()
}
// Handle preflight requests (OPTIONS method)
#[options("/<_..>")]
fn all_options() -> () {
    // Return an empty response with CORS headers
    ()
}

#[delete("/documents/<id>")]
async fn delete_document(_api_key: ApiKey, client: &State<Client>, id: &str) -> Result<Status, Custom<String>> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let object_id = ObjectId::parse_str(id).map_err(|_| {
        Custom(Status::BadRequest, format!("Invalid document ID: {}", id))
    })?;

    let result = collection.delete_one(doc! { "_id": object_id }, None).await.map_err(|e| {
        Custom(Status::InternalServerError, format!("Failed to delete document: {}", e))
    })?;

    if result.deleted_count == 1 {
        Ok(Status::NoContent)
    } else {
        Err(Custom(Status::NotFound, format!("Document not found: {}", id)))
    }
}
#[delete("/pdf/<document_id>")]
async fn delete_pdf(_api_key: ApiKey, client: &State<Client>, document_id: &str) -> Result<Status, Custom<String>> {
    // Explicitly define the collection type
    let collection: mongodb::Collection<mongodb::bson::Document> = client.database("document_manager").collection("pdfs");

    let pdf_entry = collection.find_one(doc! { "document_id": document_id }, None)
        .await.map_err(|e| {
        Custom(Status::InternalServerError, format!("Failed to find PDF: {}", e))
    })?;

    if let Some(pdf_entry) = pdf_entry {
        let storage_filename = pdf_entry.get_str("storage_filename").unwrap();
        let pdf_path = format!("pdfs/{}", storage_filename);

        std::fs::remove_file(pdf_path).map_err(|e| {
            Custom(Status::InternalServerError, format!("Failed to delete PDF file: {}", e))
        })?;

        collection.delete_one(doc! { "document_id": document_id }, None).await.map_err(|e| {
            Custom(Status::InternalServerError, format!("Failed to delete PDF metadata: {}", e))
        })?;

        Ok(Status::NoContent)
    } else {
        Err(Custom(Status::NotFound, format!("PDF not found for document ID: {}", document_id)))
    }
}

#[put("/documents/<id>", data = "<updated_doc>")]
async fn update_document(_api_key: ApiKey, client: &State<Client>, id: &str, updated_doc: Json<Document>) -> Result<Status, Custom<String>> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let object_id = ObjectId::parse_str(id).map_err(|_| {
        Custom(Status::BadRequest, format!("Invalid document ID: {}", id))
    })?;

    let update_doc = doc! {
        "$set": {
            "title": &updated_doc.title,
            "content": &updated_doc.content,
            "tags": &updated_doc.tags,
            "summary": &updated_doc.summary,
            "rating": updated_doc.rating,
        }
    };

    //println!("{:?}", update_doc);

    let result = collection.update_one(doc! { "_id": object_id }, update_doc, None).await.map_err(|e| {
        Custom(Status::InternalServerError, format!("Failed to update document: {}", e))
    })?;

    if result.matched_count == 1 {
        Ok(Status::NoContent)
    } else {
        Err(Custom(Status::NotFound, format!("Document not found: {}", id)))
    }
}

pub struct ApiKeyManager {
    api_keys: Vec<String>,
}

impl ApiKeyManager {
    // Initialize the ApiKeyManager as a singleton
    fn new() -> Self {
        // Load API keys from file on startup
        let api_keys = Self::load_api_keys_from_file("config/api.keys");
        ApiKeyManager { api_keys }
    }

    // Static method to load API keys from a file
    fn load_api_keys_from_file(file_path: &str) -> Vec<String> {
        let content = fs::read_to_string(file_path).expect("Failed to read API keys file");
        content
            .lines()
            .map(|line| line.trim().to_string())
            .collect()
    }

    // Check if an API key is valid
    pub fn is_valid_api_key(&self, api_key: &str) -> bool {
        self.api_keys.contains(&api_key.to_string())
    }
}

// Static instance for the singleton
lazy_static::lazy_static! {
    static ref API_KEY_MANAGER: Arc<ApiKeyManager> = Arc::new(ApiKeyManager::new());
}
// Define a struct to represent the API key
pub struct ApiKey(String);

#[rocket::async_trait]
impl<'r> FromRequest<'r> for ApiKey {
    type Error = ();

    async fn from_request(request: &'r Request<'_>) -> Outcome<Self, Self::Error> {
        // Get the API key from the `x-api-key` header
        if let Some(api_key) = request.headers().get_one("x-api-key") {
            // Use the singleton to check if the API key is valid
            if API_KEY_MANAGER.is_valid_api_key(api_key) {
                return Outcome::Success(ApiKey(api_key.to_string()));
            }
        }

        println!("Unauthorized - Invalid or missing API key.");
        Outcome::Error((Status::Unauthorized, ()))
    }
}


#[rocket::launch]
async fn rocket() -> _ {
    // Initialize the MongoDB client
    let client_options = ClientOptions::parse("mongodb://localhost:27017").await.unwrap();
    let client = Client::with_options(client_options).unwrap();


    rocket::build()
        .manage(client)
        .attach(CORS)  // Attach the CORS fairing
        .mount("/", routes![get_documents, get_document_by_id, search_documents, create_document, all_options, get_pdf, upload_pdf, delete_document, delete_pdf, update_document])
}

