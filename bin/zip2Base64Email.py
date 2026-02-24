import base64
import os

def zip_to_base64(file_path):
    if not os.path.exists(file_path):
        return "Error: File not found."

    # Read the binary data from the ZIP file
    with open(file_path, "rb") as zip_file:
        encoded_string = base64.b64encode(zip_file.read()).decode('utf-8')

    # Formatting for better email readability (optional)
    # This breaks the long string into lines of 76 characters
    formatted_string = '\n'.join(encoded_string[i:i+76] for i in range(0, len(encoded_string), 76))

    header = f"--- START BASE64 ZIP: {os.path.basename(file_path)} ---"
    footer = "--- END BASE64 ZIP ---"

    return f"{header}\n\n{formatted_string}\n\n{footer}"

# Usage
# Change 'your_file.zip' to the path of your ZIP file
print(zip_to_base64("your_file.zip"))
