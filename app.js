require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const multer = require('multer');
const AWS = require('aws-sdk');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

app.set('view engine', 'ejs');
app.use(express.urlencoded({ extended: true }));
app.use(express.static('public'));

// Setup MySQL Connection Pool
const pool = mysql.createPool({
    host: process.env.DB_HOST || 'db',
    user: process.env.DB_USER || 'newshub_user',
    password: process.env.DB_PASSWORD || 'newshub_pass',
    database: process.env.DB_NAME || 'newshub_db',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Setup AWS S3
const s3 = new AWS.S3({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    region: process.env.AWS_REGION || 'us-east-1'
});

// Setup Multer for memory storage (we will upload direct to S3)
const upload = multer({ storage: multer.memoryStorage() });

// Initialize DB table if not exists
async function initDb() {
    try {
        const connection = await pool.getConnection();
        await connection.query(`
            CREATE TABLE IF NOT EXISTS articles (
                id INT AUTO_INCREMENT PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                content TEXT NOT NULL,
                image_url VARCHAR(500),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);
        connection.release();
        console.log("Database initialized successfully.");
    } catch (err) {
        console.error("Database initialization failed. Waiting to retry...", err.message);
        setTimeout(initDb, 5000);
    }
}
initDb();

// Routes
app.get('/', async (req, res) => {
    try {
        const [rows] = await pool.query('SELECT * FROM articles ORDER BY created_at DESC');
        res.render('index', { articles: rows });
    } catch (err) {
        console.error(err);
        res.status(500).send("Database error: Make sure database is running.");
    }
});

app.get('/category/:name', async (req, res) => {
    try {
        const category = req.params.name;
        const [rows] = await pool.query('SELECT * FROM articles WHERE category = ? ORDER BY created_at DESC', [category]);
        res.render('category', { articles: rows, currentCategory: category });
    } catch (err) {
        console.error(err);
        res.status(500).send("Error fetching category.");
    }
});

app.get('/dashboard', async (req, res) => {
    try {
        const [rows] = await pool.query('SELECT * FROM articles ORDER BY created_at DESC');
        res.render('dashboard', { articles: rows });
    } catch (err) {
        console.error(err);
        res.status(500).send("Error fetching articles.");
    }
});

app.post('/articles/:id/delete', async (req, res) => {
    try {
        const { id } = req.params;
        await pool.query('DELETE FROM articles WHERE id = ?', [id]);
        res.redirect('/dashboard');
    } catch (err) {
        console.error(err);
        res.status(500).send("Error deleting article.");
    }
});

app.post('/articles', upload.single('image'), async (req, res) => {
    try {
        const { title, content, category, is_important } = req.body;
        const important = is_important === 'on' ? 1 : 0;
        const cat = category || 'General';
        let imageUrl = null;

        if (req.file && process.env.S3_BUCKET_NAME) {
            const params = {
                Bucket: process.env.S3_BUCKET_NAME,
                Key: `news-images/${Date.now()}-${req.file.originalname}`,
                Body: req.file.buffer,
                ContentType: req.file.mimetype,
                ACL: 'public-read'
            };
            
            try {
               const uploadResult = await s3.upload(params).promise();
               imageUrl = uploadResult.Location;
            } catch (s3err) {
               console.error("S3 upload error (proceeding without image):", s3err);
            }
        }

        const query = 'INSERT INTO articles (title, content, image_url, category, is_important) VALUES (?, ?, ?, ?, ?)';
        await pool.query(query, [title, content, imageUrl, cat, important]);

        res.redirect('/');
    } catch (err) {
        console.error(err);
        res.status(500).send("Error saving article");
    }
});

app.listen(port, () => {
    console.log(`NewsHub running on port ${port}`);
});
