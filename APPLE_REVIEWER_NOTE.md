# Apple Reviewer Notes: SequenceStitch

## Overview
SequenceStitch is a high-performance macOS application designed for converting image sequences (PNG, JPEG) and PDF documents into professional-quality video files. It is optimized for Apple Silicon and uses hardware acceleration (VideoToolbox) for efficient encoding.

## Key Features for Review
1. **Comparison Mode (PRO Feature)**: Allows users to import two different sequences (A and B) and export a side-by-side or top-bottom comparison video. Perfect for before/after validation.
2. **Time-lapse Calculator**: Automatically calculates the required frame duration based on the user's target final video length.
3. **PDF Support**: Directly import multi-page PDFs; each page is processed as a separate frame at high resolution (300 DPI).
4. **Video Frame Extraction**: Users can import an existing video to extract its frames for further processing or restitching.

## Test Assets Instructions
We have provided a set of test assets in the repository/package to demonstrate these features:

- **JPEGs (`test_assets/jpegs/`)**: 19 high-quality landscape photos for standard time-lapse mapping.
- **PNGs (`test_assets/pngs/`)**: 10 high-quality frames for testing transparent or lossless sequences.
- **PDFs (`test_assets/pdfs/`)**: Individual PDF copies of the test images to verify "One PDF = One Frame" handling.
- **Test Videos (`test_assets/*.mp4`)**: Two sample movies (`test_video_5mb.mp4` and `test_video_pattern_5mb.mp4`) provided specifically to test the **Video Import & Frame Extraction** feature.

### Suggested Review Flow
1. **Standard Mode**: Drag the contents of the `jpegs` or `pngs` folder into the grid. Play the preview. Export as MP4.
2. **Comparison Mode**: Toggle "Comparison Mode" in the toolbar. Drag JPEG images 1-10 to the left panel (A) and 11-19 to the right panel (B). Choose "Side-by-Side" and Export.
3. **Video Import**: Drag one of the provided MP4 movies into the app. It will automatically extract frames at 10 FPS with real-time progress.
4. **PDF Mode**: Drag the individual PDF files or the consolidated PDF into the app to test document-to-video conversion.

## Privacy & Safety
- **100% Local**: No data ever leaves the user's machine.
- **Sandboxed**: Fully compliant with Mac App Store sandbox requirements.
- **Offline**: No internet connection required.

---
Thank you for reviewing SequenceStitch!
