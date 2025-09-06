# ml_service/src/prediction/predictor.py
import os
import joblib
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
import logging
from datetime import datetime
from typing import Dict, Any, Optional

from ..utils.database import DatabaseManager

logger = logging.getLogger(__name__)

class SafetyPredictor:
    """Main class for safety prediction using ML models"""
    
    def __init__(self, config):
        self.config = config
        self.db_manager = DatabaseManager(config)
        self.model = None
        self.feature_columns = config.feature_columns
        self.model_loaded = False
        self.model_metadata = {}
        
        # Ensure models directory exists
        os.makedirs(config.model_path, exist_ok=True)
    
    def load_model(self) -> bool:
        """Load pre-trained model from disk"""
        try:
            model_path = self.config.model_file_path
            features_path = self.config.features_file_path
            
            if os.path.exists(model_path) and os.path.exists(features_path):
                self.model = joblib.load(model_path)
                self.feature_columns = joblib.load(features_path)
                
                # Load metadata if exists
                metadata_path = os.path.join(self.config.model_path, "model_metadata.json")
                if os.path.exists(metadata_path):
                    import json
                    with open(metadata_path, 'r') as f:
                        self.model_metadata = json.load(f)
                
                self.model_loaded = True
                logger.info("Model loaded successfully")
                return True
            else:
                logger.info("No saved model found")
                return False
                
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            return False
    
    def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Make safety prediction"""
        
        # Convert user_experience_level to numeric if needed
        if 'user_experience_level' in features:
            features['user_experience_numeric'] = features.pop('user_experience_level')
        
        # If no model is loaded, use fallback prediction
        if not self.model_loaded or self.model is None:
            return self._fallback_prediction(features)
        
        try:
            # Prepare features
            X = pd.DataFrame([features])
            
            # Ensure all required columns exist
            for col in self.feature_columns:
                if col not in X.columns:
                    X[col] = 0  # Default value for missing features
            
            # Select only required columns in correct order
            X = X[self.feature_columns]
            
            # Handle missing values
            X = X.fillna(X.median())
            
            # Make prediction
            prediction = self.model.predict(X)[0]
            
            # Calculate confidence based on tree predictions variance
            tree_predictions = np.array([tree.predict(X)[0] for tree in self.model.estimators_])
            prediction_std = np.std(tree_predictions)
            confidence = max(0.1, min(1.0, 1.0 / (1.0 + prediction_std)))
            
            # Ensure prediction is within valid range
            prediction = max(1.0, min(5.0, prediction))
            
            return {
                "predicted_safety": round(prediction, 2),
                "confidence": round(confidence, 3),
                "model_version": self.model_metadata.get("version", "1.0"),
                "model_type": "RandomForestRegressor",
                "fallback_used": False
            }
            
        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            return self._fallback_prediction(features)
    
    def _fallback_prediction(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Fallback prediction using rule-based scoring"""
        try:
            # Simple weighted average of scores
            lighting_score = features.get('lighting_score', 50)
            business_score = features.get('business_score', 50)
            crime_score = features.get('crime_score', 50)
            reports_score = features.get('reports_score', 50)
            
            # Convert percentage scores to 1-5 scale
            base_score = (
                lighting_score * 0.3 +
                business_score * 0.25 +
                crime_score * 0.2 +
                reports_score * 0.25
            ) / 100 * 5
            
            # Apply time-based adjustments
            time_of_day = features.get('time_of_day', 12)
            if 22 <= time_of_day or time_of_day <= 6:  # Night time
                base_score *= 0.8
            elif 18 <= time_of_day <= 21:  # Evening
                base_score *= 0.9
            
            # Apply user experience adjustment
            user_exp = features.get('user_experience_numeric', 1)
            if user_exp >= 3:  # Trusted/Expert users might have different perception
                base_score *= 1.05
            
            # Apply reports encountered penalty
            reports_count = features.get('encountered_reports_count', 0)
            if reports_count > 0:
                base_score *= (0.95 ** reports_count)
            
            prediction = max(1.0, min(5.0, base_score))
            
            return {
                "predicted_safety": round(prediction, 2),
                "confidence": 0.5,  # Medium confidence for rule-based
                "model_version": "fallback_v1.0",
                "model_type": "rule_based",
                "fallback_used": True
            }
            
        except Exception as e:
            logger.error(f"Fallback prediction failed: {e}")
            return {
                "predicted_safety": 3.0,  # Neutral prediction
                "confidence": 0.3,
                "model_version": "emergency_fallback",
                "model_type": "constant",
                "fallback_used": True
            }
    
    def train_model(self) -> Dict[str, Any]:
        """Train or retrain the ML model"""
        return {
            "success": False,
            "message": "Training not implemented yet"
        }
    
    def get_model_info(self) -> dict:
        """Get information about current model"""
        if not self.model_loaded:
            return {
                "status": "No model loaded",
                "model_loaded": False
            }
        
        return {
            "model_loaded": True,
            "model_type": "RandomForestRegressor",
            "feature_columns": self.feature_columns
        }
    
    def get_data_status(self) -> dict:
        """Get status of training data"""
        return {
            "status": "Database connection not implemented yet",
            "has_sufficient_data": False
        }