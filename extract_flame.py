from PIL import Image, ImageDraw

def extract_flame_only():
    img = Image.open("assets/icon_koyilandy.png").convert("RGBA")
    width, height = img.size
    
    # The previous bounding box of the ring was around (179, 170) to (842, 918)
    # The center is approximately (510, 544)
    # The ring has a radius of roughly 330.
    # The flame is in the middle. Let's find the bounding box of the flame by 
    # searching from the center outwards, or just masking out the ring.
    
    # Let's create a mask that is black outside a certain radius (to cut the ring)
    # and white inside.
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    
    # We'll use a bounding box that tightly fits the flame, excluding the ring.
    # The flame is probably within x: 300 to 720, y: 250 to 800.
    # Let's draw an ellipse for the mask that is safely inside the ring.
    # Center (510, 544). Radius ~270 should cut the ring but keep the flame.
    # Let's use an ellipse that is taller than it is wide.
    # Left: 510 - 240 = 270
    # Right: 510 + 240 = 750
    # Top: 544 - 320 = 224
    # Bottom: 544 + 320 = 864
    
    draw.ellipse((260, 220, 760, 880), fill=255)
    
    # Apply mask to image to remove the ring
    flame_only = Image.new("RGBA", (width, height), (0,0,0,0))
    flame_only.paste(img, (0,0), mask)
    
    # Now, let's remove the dark grey background. We only want the bright green pixels.
    pixels = flame_only.load()
    min_x, max_x = width, 0
    min_y, max_y = height, 0
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a > 0:
                # If it's a dark background pixel (greyish), make it transparent
                if g > 50 and g > r + 10 and g > b + 10:
                    # It's part of the flame
                    if x < min_x: min_x = x
                    if x > max_x: max_x = x
                    if y < min_y: min_y = y
                    if y > max_y: max_y = y
                else:
                    pixels[x, y] = (0, 0, 0, 0)
                    
    # Now crop exactly to the flame
    if min_x < max_x and min_y < max_y:
        final_flame = flame_only.crop((min_x, min_y, max_x, max_y))
        
        # Resize to fill the adaptive icon safe area (Android safe area is ~66%)
        # So maximum dimension should be around 768.
        max_size = 768
        w, h = final_flame.size
        ratio = min(max_size / w, max_size / h)
        new_w, new_h = int(w * ratio), int(h * ratio)
        
        final_flame = final_flame.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Paste into 1024x1024 transparent canvas
        new_img = Image.new("RGBA", (1024, 1024), (0,0,0,0))
        offset_x = (1024 - new_w) // 2
        offset_y = (1024 - new_h) // 2
        
        new_img.paste(final_flame, (offset_x, offset_y), final_flame)
        
        new_img.save("assets/icon_koyilandy_foreground.png")
        print("Successfully isolated the flame, removed the ring and background, and resized.")
    else:
        print("Failed to isolate the flame.")

if __name__ == "__main__":
    extract_flame_only()
