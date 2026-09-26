from PIL import Image, ImageChops

def enlarge_flame(image_path):
    img = Image.open(image_path).convert("RGBA")
    
    # We want to find the bounding box of the non-transparent, non-black parts
    # First, let's just get the bounding box of the alpha channel if it's transparent
    bg = Image.new("RGBA", img.size, (0, 0, 0, 0))
    diff = ImageChops.difference(img, bg)
    bbox = diff.getbbox()
    
    # If the background is actually solid black, we need to subtract black instead
    if not bbox or bbox == (0, 0, img.size[0], img.size[1]):
        # Let's try converting to RGB and subtracting black
        rgb_img = img.convert("RGB")
        black_bg = Image.new("RGB", rgb_img.size, (0, 0, 0))
        diff = ImageChops.difference(rgb_img, black_bg)
        # Convert difference to grayscale
        diff_gray = diff.convert("L")
        # Apply a threshold to ignore near-black pixels
        diff_gray = diff_gray.point(lambda p: 255 if p > 20 else 0)
        bbox = diff_gray.getbbox()
    
    if bbox:
        # Crop to the bounding box of the flame
        flame = img.crop(bbox)
        
        # Calculate new size (Android adaptive icons safe zone is middle 66%)
        # Let's scale it to fill about 75% of the 1024x1024 canvas (768x768 max)
        max_size = 768
        
        # Keep aspect ratio
        w, h = flame.size
        ratio = min(max_size / w, max_size / h)
        new_w, new_h = int(w * ratio), int(h * ratio)
        
        flame_resized = flame.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Create a new transparent 1024x1024 image
        new_img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        
        # Paste the resized flame in the center
        offset_x = (1024 - new_w) // 2
        offset_y = (1024 - new_h) // 2
        
        # We use the resized flame as the mask so transparency is preserved
        new_img.paste(flame_resized, (offset_x, offset_y), flame_resized)
        
        # Save it
        new_img.save(image_path)
        print("Successfully cropped, enlarged and saved to", image_path)
    else:
        print("Could not find a valid bounding box.")

if __name__ == "__main__":
    enlarge_flame("assets/icon_koyilandy_foreground.png")
