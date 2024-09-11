#[macro_use] extern crate rocket;

use mongodb::{Client, options::ClientOptions, bson::doc, bson::oid::ObjectId};
use mongodb::bson;
use rocket::futures::TryStreamExt;
use rocket::serde::{json::Json, Deserialize, Serialize};
use rocket::State;

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

#[get("/documents")]
async fn get_documents(client: &State<Client>) -> Json<Vec<Document>> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let cursor = collection.find(None, None).await.expect("Failed to find documents");
    let documents: Vec<Document> = cursor.try_collect().await.expect("Error collecting documents");
    Json(documents)
}

#[get("/documents/<id>")]
async fn get_document_by_id(client: &State<Client>, id: &str) -> Option<Json<Document>> {
    let collection = client.database("document_manager").collection::<Document>("documents");
    let object_id = ObjectId::parse_str(id).ok()?;
    let filter = doc! { "_id": object_id };
    let document = collection.find_one(filter, None).await.ok()??;
    Some(Json(document))
}

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

#[launch]
async fn rocket() -> _ {
    // Initialize the MongoDB client
    let client_options = ClientOptions::parse("mongodb://localhost:27017").await.unwrap();
    let client = Client::with_options(client_options).unwrap();

    rocket::build()
        .manage(client)
        .mount("/", routes![get_documents, get_document_by_id, search_documents, create_document])
}
