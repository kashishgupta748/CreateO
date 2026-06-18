const express = require("express");
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const { getPromptForStyle } = require("../services/stylePromptService");
const { generateStyledImage } = require("../services/openaiService");

const router = express.Router();

// Multer configuration for temporary uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = path.join(__dirname, '..', '..', 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    cb(null, `upload_${Date.now()}_${file.originalname}`);
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: function (req, file, cb) {
    const filetypes = /jpeg|jpg|png/;
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = filetypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error("Only images (jpeg, jpg, png) are allowed"));
    }
  }
});

router.post("/", upload.single("image"), async (req, res) => {
  let tempFilePath = null;
  try {
    const style = req.body.style;
    const imageFile = req.file;

    // Validate image file
    if (!imageFile) {
      return res.status(400).json({ error: "Image file is required" });
    }
    tempFilePath = imageFile.path;

    // Validate style
    const allowedStyles = ["sketchbook", "anime", "watercolor"];
    if (!style || !allowedStyles.includes(style.toLowerCase())) {
      return res.status(400).json({ error: `Invalid style. Allowed values: ${allowedStyles.join(", ")}` });
    }

    // Determine host URL for returned asset link
    const protocol = req.headers['x-forwarded-proto'] || req.protocol;
    const host = req.get('host');
    const hostUrl = `${protocol}://${host}`;

    // Get style prompt mapping
    const prompt = getPromptForStyle(style);

    console.log(`[Generate Route] Request received for style: ${style}. File path: ${tempFilePath}`);

    // Call AI generation pipeline
    const outputImageURL = await generateStyledImage(tempFilePath, prompt, style.toLowerCase(), hostUrl);

    return res.json({
      success: true,
      outputImageURL: outputImageURL
    });

  } catch (error) {
    console.error(`[Generate Route] Error:`, error);
    res.status(500).json({ error: error.message || "Failed to stylize image" });
  } finally {
    // Delete the temporary uploaded image
    if (tempFilePath && fs.existsSync(tempFilePath)) {
      fs.unlink(tempFilePath, (err) => {
        if (err) console.error(`[Generate Route] Failed to delete temp file ${tempFilePath}:`, err);
      });
    }
  }
});

module.exports = router;
