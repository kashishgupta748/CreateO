require("dotenv").config();
const express = require("express");
const cors = require("cors");
const path = require("path");
const generateRouter = require("./src/routes/generate");

const app = express();
const PORT = process.env.PORT || 3000;

// Enable CORS for all requests (crucial for local testing from simulator or device)
app.use(cors());

// Body parsing middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static assets from public folder
app.use(express.static(path.join(__dirname, "public")));

// Register routes
app.use("/api/generate", generateRouter);

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({ status: "healthy", timestamp: new Date() });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error("Unhandled Error:", err);
  res.status(500).json({ error: err.message || "Internal Server Error" });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`==========================================`);
  console.log(`🚀 CreateO Backend running on port ${PORT}`);
  console.log(`📂 Serving static files from public/`);
  console.log(`🔑 OpenAI API Key: ${process.env.OPENAI_API_KEY ? 'CONFIGURED' : 'NOT CONFIGURED (Mock Mode Active)'}`);
  console.log(`==========================================`);
});
