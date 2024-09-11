
#[macro_use] extern crate rocket;

use mongodb::{Client, options::ClientOptions, bson::doc, bson::oid::ObjectId};
use mongodb::bson;
use rocket::futures::TryStreamExt;
use rocket::serde::{json::Json, Deserialize, Serialize};
use rocket::http::Header;
use rocket::{State, Request, Response};
use rocket::fairing::{Fairing, Info, Kind};

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
    }
}

// Route to get all documents
#[get("/documents")]
async fn get_documents(client: &State<Client>) -> Json<Vec<Document>> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let cursor = collection.find(None, None).await.expect("Failed to find documents");
    let documents: Vec<Document> = cursor.try_collect().await.expect("Error collecting documents");

    Json(documents)
}

// Route to get a document by ID
#[get("/documents/<id>")]
async fn get_document_by_id(client: &State<Client>, id: &str) -> Option<Json<Document>> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let object_id = ObjectId::parse_str(id).ok()?;
    let filter = doc! { "_id": object_id };
    let document = collection.find_one(filter, None).await.ok()??;

    Some(Json(document))
}

// Route to handle search
#[get("/search?<term>")]
async fn search_documents(client: &State<Client>, term: String) -> Json<Vec<Document>> {
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
async fn create_document(client: &State<Client>, document: Json<Document>) -> Json<ObjectId> {
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

// Handle preflight requests (OPTIONS method)
#[options("/<_..>")]
fn all_options() -> () {
    // Return an empty response with CORS headers
    ()
}

#[rocket::launch]
async fn rocket() -> _ {
    // Initialize the MongoDB client
    let client_options = ClientOptions::parse("mongodb://localhost:27017").await.unwrap();
    let client = Client::with_options(client_options).unwrap();

    rocket::build()
        .manage(client)
        .attach(CORS)  // Attach the CORS fairing
        .mount("/", routes![get_documents, get_document_by_id, search_documents, create_document, all_options])
}

