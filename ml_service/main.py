# ml_service/main.py
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import os
from datetime import datetime
import logging

from src.utils.config import Config
from src.prediction.predictor import SafetyPredictor

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="City Path ML Service",
    description="Machine Learning API for route safety prediction",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Node.js backend
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global predictor instance
predictor = None

class RouteFeatures(BaseModel):
    lighting_score: float
    business_score: float
    crime_score: float
    reports_score: float
    route_length_km: float
    time_of_day: int  # 0-23
    day_of_week: int  # 0-6 (0=Sunday)
    month: int  # 1-12
    season: int  # 1-4
    encountered_reports_count: int = 0
    user_reputation: int = 50
    user_experience_level: int = 1  # 1-4

class PredictionResponse(BaseModel):
    predicted_safety: float
    confidence: float
    model_version: str
    model_type: str
    fallback_used: bool = False

@app.on_event("startup")
async def startup_event():
    """Initialize ML model on startup"""
    global predictor
    
    try:
        config = Config()
        predictor = SafetyPredictor(config)
        
        # Try to load existing model
        if not predictor.load_model():
            logger.info("No existing model found. Will use fallback predictions.")
            logger.info("Train a model using /train endpoint when data is available.")
        else:
            logger.info("Model loaded successfully")
            
    except Exception as e:
        logger.error(f"Failed to initialize predictor: {e}")
        predictor = None

@app.get("/")
async def root():
    return {
        "service": "City Path ML Service",
        "version": "1.0.0",
        "status": "active",
        "endpoints": ["/predict", "/train", "/health", "/model-info"]
    }

@app.get("/health")
async def health_check():
    model_status = "loaded" if predictor and predictor.model_loaded else "not_loaded"
    
    return {
        "status": "healthy",
        "model_status": model_status,
        "timestamp": datetime.now().isoformat(),
        "service": "ml_service"
    }

@app.post("/predict", response_model=PredictionResponse)
async def predict_safety(features: RouteFeatures):
    """Predict safety score for route features"""
    
    if not predictor:
        raise HTTPException(status_code=503, detail="ML service not initialized")
    
    try:
        result = predictor.predict(features.dict())
        
        return PredictionResponse(
            predicted_safety=result["predicted_safety"],
            confidence=result["confidence"],
            model_version=result["model_version"],
            model_type=result["model_type"],
            fallback_used=result.get("fallback_used", False)
        )
        
    except Exception as e:
        logger.error(f"Prediction failed: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

@app.post("/train")
async def train_model():
    """Train/retrain the ML model with latest data"""
    
    if not predictor:
        raise HTTPException(status_code=503, detail="ML service not initialized")
    
    try:
        result = predictor.train_model()
        
        return {
            "success": result["success"],
            "message": result["message"],
            "metrics": result.get("metrics", {}),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Training failed: {e}")
        raise HTTPException(status_code=500, detail=f"Training failed: {str(e)}")

@app.get("/model-info")
async def get_model_info():
    """Get information about the current model"""
    
    if not predictor:
        return {"status": "ML service not initialized"}
    
    try:
        info = predictor.get_model_info()
        return info
        
    except Exception as e:
        logger.error(f"Failed to get model info: {e}")
        return {"error": f"Failed to get model info: {str(e)}"}

@app.get("/data-status")
async def get_data_status():
    """Check available training data"""
    
    if not predictor:
        return {"status": "ML service not initialized"}
    
    try:
        status = predictor.get_data_status()
        return status
        
    except Exception as e:
        logger.error(f"Failed to get data status: {e}")
        return {"error": f"Failed to get data status: {str(e)}"}

if __name__ == "__main__":
    # Load config
    config = Config()
    
    # Run the app
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=config.api_port,
        reload=config.environment == "development"
    )