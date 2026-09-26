from PIL import Image

def process_icon(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    pixels = img.load()
    width, height = img.size
    
    # We want to extract only the green flame and the green ring
    # and make the background completely transparent
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # A pixel is "greenish" if green is significantly higher than red and blue
            # Or if it's very bright
            # The grey background has roughly equal r, g, b
            if g > r + 15 and g > b + 15:
                # Keep it, it's part of the flame/ring
                pass
            else:
                # Make it transparent
                pixels[x, y] = (0, 0, 0, 0)
                
    # Now find the bounding box of the non-transparent pixels
    bbox = img.getbbox()
    if bbox:
        # Crop to just the glowing green circle
        flame = img.crop(bbox)
        
        # We want to scale this to fill the safe area
        # Android safe area is 66% of the icon, so out of 1024, it's ~675.
        # But we also have a black background adaptive layer.
        # Let's scale the flame to exactly 768x768 (75% of 1024).
        max_size = 768
        w, h = flame.size
        ratio = min(max_size / w, max_size / h)
        new_w, new_h = int(w * ratio), int(h * ratio)
        
        flame_resized = flame.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Create a new transparent 1024x1024 image
        new_img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        
        # Paste the resized flame in the center
        offset_x = (1024 - new_w) // 2
        offset_y = (1024 - new_h) // 2
        new_img.paste(flame_resized, (offset_x, offset_y), flame_resized)
        
        new_img.save(output_path)
        print("Successfully extracted flame and saved to", output_path)
    else:
        print("Could not find any green pixels.")

if __name__ == "__main__":
    process_icon("assets/icon_koyilandy.png", "assets/icon_koyilandy_foreground.png")
