import json
import requests

def lambda_handler(event, context):
    # Replace with your predefined values
    subnet_id = "<Your Private Subnet ID>"
    name = "<Your Full Name>"
    email = "<Your Email Address>"
    
    # Construct the payload
    payload = {
        "subnet_id": subnet_id,
        "name": name,
        "email": email
    }
    
    # Convert the payload to JSON
    json_payload = json.dumps(payload)
    
    # Set the headers
    headers = {
        'X-Company-Auth': 'test',
        'Content-Type': 'application/json'
    }
    
    # Set the API endpoint URL
    endpoint_url = 'https://jsonplaceholder.typicode.com/posts'
    
    try:
        # Make the POST request to the API endpoint
        response = requests.post(endpoint_url, data=json_payload, headers=headers)
        
        # Check the response status code
        if response.status_code == 200:
            print("API request successful")
        else:
            print(f"API request failed with status code: {response.status_code}")
    
    except Exception as e:
        print(f"Error occurred during API request: {str(e)}")
