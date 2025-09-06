# ml_service/src/utils/config.py
import os
from typing import Optional
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class Config:
    """Configuration class for ML service"""
    
    def __init__(self):
        # Environment
        self.environment = os.getenv("ENVIRONMENT", "development")
        
        # API Configuration
        self.api_port = int(os.getenv("ML_API_PORT", "5000"))
        self.api_host = os.getenv("ML_API_HOST", "0.0.0.0")
        
        # Database Configuration
        self.db_host = os.getenv("DB_HOST", "localhost")
        self.db_port = int(os.getenv("DB_PORT", "5432"))
        self.db_name = os.getenv("DB_NAME", "city_path")
        self.db_user = os.getenv("DB_USER", "postgres")
        self.db_password = os.getenv("DB_PASSWORD", "password")
        
        # Model Configuration
        self.model_path = os.getenv("MODEL_PATH", "models/")
        self.model_name = os.getenv("MODEL_NAME", "random_forest_v1.pkl")
        self.features_file = os.getenv("FEATURES_FILE", "feature_columns.pkl")
        
        # Training Configuration
        self.min_training_samples = int(os.getenv("MIN_TRAINING_SAMPLES", "50"))
        self.max_training_samples = int(os.getenv("MAX_TRAINING_SAMPLES", "10000"))
        self.test_size = float(os.getenv("TEST_SIZE", "0.2"))
        self.cv_folds = int(os.getenv("CV_FOLDS", "5"))
        self.random_state = int(os.getenv("RANDOM_STATE", "42"))
        
        # Model Hyperparameters (RandomForest)
        self.rf_n_estimators = int(os.getenv("RF_N_ESTIMATORS", "100"))
        self.rf_max_depth = self._parse_int_or_none(os.getenv("RF_MAX_DEPTH", "10"))
        self.rf_min_samples_split = int(os.getenv("RF_MIN_SAMPLES_SPLIT", "5"))
        self.rf_min_samples_leaf = int(os.getenv("RF_MIN_SAMPLES_LEAF", "2"))
        
        # Feature Engineering
        self.feature_columns = [
            'lighting_score', 'business_score', 'crime_score', 'reports_score',
            'route_length_km', 'time_of_day', 'day_of_week', 'month', 'season',
            'encountered_reports_count', 'user_reputation', 'user_experience_numeric'
        ]
        
        # Logging
        self.log_level = os.getenv("LOG_LEVEL", "INFO")
        
    def _parse_int_or_none(self, value: Optional[str]) -> Optional[int]:
        """Parse integer or return None"""
        if value is None or value.lower() == 'none':
            return None
        try:
            return int(value)
        except ValueError:
            return None
    
    @property
    def database_url(self) -> str:
        """Get database connection URL"""
        return f"postgresql://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"
    
    @property
    def model_file_path(self) -> str:
        """Get full path to model file"""
        return os.path.join(self.model_path, self.model_name)
    
    @property
    def features_file_path(self) -> str:
        """Get full path to features file"""
        return os.path.join(self.model_path, self.features_file)
    
    def get_rf_params(self) -> dict:
        """Get RandomForest parameters"""
        return {
            'n_estimators': self.rf_n_estimators,
            'max_depth': self.rf_max_depth,
            'min_samples_split': self.rf_min_samples_split,
            'min_samples_leaf': self.rf_min_samples_leaf,
            'random_state': self.random_state,
            'n_jobs': -1
        }