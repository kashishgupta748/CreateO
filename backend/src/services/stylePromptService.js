const STYLE_PROMPTS = {
  sketchbook: `
Transform the uploaded photo into a colorful hand-drawn sketchbook illustration.
Keep the main subject, people, buildings, and composition recognizable.
Use pencil outlines, colored pencil texture, watercolor shading, notebook paper background,
spiral notebook binding on the left, decorative doodles, flowers, stars, books, balloons,
and handwritten scrapbook-style notes.
Make the result feel warm, youthful, emotional, and like a campus memory journal page.
Do not make it photorealistic.
`,

  anime: `
Convert the uploaded photo into a vibrant anime-style illustration.
Keep the same person and composition recognizable.
Use clean anime line art, expressive eyes, soft cel shading, bright colors,
and polished background details.
Do not make it realistic.
`,

  watercolor: `
Turn the uploaded photo into a soft watercolor painting.
Preserve the subject and overall composition.
Use gentle washes, artistic edges, pastel tones, and painterly texture.
`
};

function getPromptForStyle(style) {
  const normalized = (style || "").toLowerCase().trim();
  return STYLE_PROMPTS[normalized] || STYLE_PROMPTS["sketchbook"];
}

module.exports = { getPromptForStyle, STYLE_PROMPTS };
