from PIL import Image

def fix_icon():
    img = Image.open("assets/icon_koyilandy.png").convert("RGBA")
    width, height = img.size
    pixels = img.load()
    
    min_x, max_x = width, 0
    min_y, max_y = height, 0
    
    # Find the bright green ring and flame
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # strict bright green
            if g > 100 and g > r * 1.5 and g > b * 1.5:
                # Avoid the reflection at the bottom which is usually lower down
                # Let's just find the bounding box
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y

    print(f"Detected bounding box: {min_x}, {min_y} to {max_x}, {max_y}")
    
    # If we found a valid box
    if min_x < max_x and min_y < max_y:
        # The reflection might have stretched max_y downwards.
        # The true ring is usually a circle, so width should roughly equal height.
        w = max_x - min_x
        h = max_y - min_y
        center_x = min_x + w // 2
        center_y = min_y + h // 2
        
        # Assume the true radius is half the width (since reflection only affects height)
        radius = w // 2
        
        # Crop to the exact square containing the circle
        box = (center_x - radius, center_y - radius, center_x + radius, center_y + radius)
        cropped = img.crop(box)
        
        # Now make a circular mask to remove anything outside the ring (like the reflection)
        mask = Image.new("L", cropped.size, 0)
        from PIL import ImageDraw
        draw = ImageDraw.Draw(mask)
        draw.ellipse((0, 0, cropped.size[0], cropped.size[1]), fill=255)
        
        # Apply mask
        cropped_rgba = cropped.convert("RGBA")
        final_flame = Image.new("RGBA", cropped.size, (0,0,0,0))
        final_flame.paste(cropped_rgba, (0,0), mask)
        
        # Now scale this to fill the 1024x1024 canvas (adaptive safe zone is ~700-800)
        max_size = 850
        final_flame = final_flame.resize((max_size, max_size), Image.Resampling.LANCZOS)
        
        new_img = Image.new("RGBA", (1024, 1024), (0,0,0,0))
        offset = (1024 - max_size) // 2
        new_img.paste(final_flame, (offset, offset), final_flame)
        
        new_img.save("assets/icon_koyilandy_foreground.png")
        print("Cropped to perfect circle, masked, resized and saved.")

if __name__ == "__main__":
    fix_icon()
