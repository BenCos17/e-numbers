# E-Number Lookup API Documentation

This API provides CRUD (Create, Read, Update, Delete) operations for managing E-number data.

## Base URL

    http://localhost:5000/api/enumbers

---

## Endpoints

### 1. List or Search E-numbers

**GET /api/enumbers**

- Returns all E-numbers, or filters by query string.
- **Query parameter:** `q` (optional, for search)

**Example:**
```
GET /api/enumbers?q=acid
```

**Response:**
```json
[
  { "code": "E 260", "name": "Acetic acid" },
  { "code": "E 355", "name": "Adipic acid" }
]
```

---

### 2. Create a New E-number

**POST /api/enumbers**

- Adds a new E-number.
- **Body:** JSON object with `code` and `name` fields.

**Example:**
```
POST /api/enumbers
Content-Type: application/json

{
  "code": "E 999",
  "name": "Example Additive"
}
```

**Response:**
```json
{
  "message": "Created",
  "enumber": { "code": "E 999", "name": "Example Additive" }
}
```

---

### 3. Update an E-number

**PUT /api/enumbers/<code>**

- Updates the name of an existing E-number by its code.
- **Body:** JSON object with `name` field.

**Example:**
```
PUT /api/enumbers/E%20999
Content-Type: application/json

{
  "name": "Updated Name"
}
```

**Response:**
```json
{
  "message": "Updated",
  "enumber": { "code": "E 999", "name": "Updated Name" }
}
```

---

### 4. Delete an E-number

**DELETE /api/enumbers/<code>**

- Deletes an E-number by its code.

**Example:**
```
DELETE /api/enumbers/E%20999
```

**Response:**
```json
{
  "message": "Deleted",
  "enumber": { "code": "E 999", "name": "Updated Name" }
}
```

---

## Error Responses

- `400 Bad Request`: Missing required fields.
- `404 Not Found`: E-number not found.
- `409 Conflict`: E-number already exists (on create).

---

## Notes
- All changes are saved to `enumbers.json`.
- The `code` field is used as the unique identifier.
- For codes with spaces or special characters, URL-encode them (e.g., `E 999` → `E%20999`).

---

## Running the Python Server and API

To start the API server, follow these steps:

1. **Make sure you have Python installed** on your system. You can download it from the official Python website if needed.
2. **Navigate to the project directory** in your terminal or command prompt.
3. **Install the required dependencies** by running the following command:
   ```bash
pip install -r requirements.txt
```
4. **Run the API server** by executing the following command:
   ```bash
python api.py
```
5. **Open a web browser** and navigate to `http://localhost:5000/api/enumbers` to access the API.

---

## Running the HTML Server

To start the HTML server, follow these steps:

1. **Navigate to the project directory** in your terminal or command prompt.
2. **Run the HTML server** by executing the following command:
   ```bash
python -m http.server
```
3. **Open a web browser** and navigate to `http://localhost:8000/enumbers.html` to access the E-Number Lookup web page.

---

## Using Postman to Add or Update E-numbers

You can use Postman to interact with the API for adding (POST) or updating (PUT) E-numbers. Here’s how:

### Adding an E-number (POST)

1. **Open Postman** and create a new request.
2. **Set the method** to `POST` and the URL to:
   ```
   http://localhost:5000/api/enumbers
   ```
3. **Go to the Body tab**:
   - Select **raw**.
   - On the right, choose **JSON** from the dropdown (not Text).
   - Enter your E-number data, for example:
     ```json
     {
       "code": "E 999",
       "name": "Example Additive"
     }
     ```
4. **Postman will automatically set** the `Content-Type: application/json` header when you select JSON.
5. **Click Send** to submit the request.
6. **Check the response** for confirmation.

### Updating an E-number (PUT)

1. **Set the method** to `PUT` and the URL to:
   ```
   http://localhost:5000/api/enumbers/E%20999
   ```
   (Replace `E%20999` with the code you want to update, URL-encoded.)
2. **Go to the Body tab**:
   - Select **raw**.
   - Choose **JSON** from the dropdown.
   - Enter the new name, for example:
     ```json
     {
       "name": "Updated Name"
     }
     ```
3. **Click Send** to update the E-number.
4. **Check the response** for confirmation.

**Tip:** If you cannot edit the Content-Type header, make sure you have selected **raw** and **JSON** in the Body tab. Postman will set the header for you. If you still have issues, try updating Postman or use `curl` as an alternative. 

---

## Deleting an E-number

To delete an E-number, send a DELETE request to the following endpoint, replacing `<code>` with the E-number code you want to remove (URL-encoded if it contains spaces):

```
DELETE /api/enumbers/<code>
```

**Example:**

To delete E 999:
```
DELETE /api/enumbers/E%20999
```

### Using Postman to Delete an E-number

1. **Open Postman** and create a new request.
2. **Set the method** to `DELETE`.
3. **Set the URL** to:
   ```
   http://localhost:5000/api/enumbers/E%20999
   ```
   (Replace `E%20999` with the code you want to delete, URL-encoded.)
4. **No body is required** for this request.
5. **Click Send** to submit the request.
6. **Check the response** for confirmation.

**Expected Response:**
```json
{
  "message": "Deleted",
  "enumber": { "code": "E 999", "name": "Example Additive" }
}
```

**Note:**
- If the E-number does not exist, the API will return a 404 error with a message indicating that the E-number was not found.
- You must have editing enabled on the server to perform this operation. 