from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ValidationError
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
import logging
import os
import sys

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
model_path = "D:\\DeepSeek-R1"  # Local path to the model
allow_origins = os.getenv("ALLOW_ORIGINS", "http://localhost:5173").split(",")

# Initialize FastAPI app
app = FastAPI()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load the model and tokenizer
try:
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    model = AutoModelForCausalLM.from_pretrained(
        model_path,
        torch_dtype=torch.float16,
        device_map="auto"
    )
except Exception as e:
    logger.error(f"Error loading model: {e}")
    sys.exit(1)  # Exit the application if the model fails to load

# Define request model
class Prompt(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=1000, description="The input prompt for text generation")

# Health check endpoint
@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": True}

# Text generation endpoint
@app.post("/generate")
async def generate_text(prompt: Prompt):
    try:
        logger.info(f"Received prompt: {prompt.prompt}")
        
        # Tokenize input
        inputs = tokenizer(prompt.prompt, return_tensors="pt").to(model.device)
        
        # Generate response
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_length=2048,
                temperature=0.7,
                top_p=0.95,
                pad_token_id=tokenizer.eos_token_id
            )
        
        # Decode and return response
        response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        logger.info(f"Generated response: {response}")
        return {"response": response}
    
    except ValidationError as e:
        logger.error(f"Validation error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error generating text: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Run the application
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)