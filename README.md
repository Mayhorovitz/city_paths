# City Paths

**City Paths** is a community-powered safety navigation app that helps people move through cities more safely by suggesting routes optimized for street lighting, open businesses, crime data, and real-time user reports.

![citypaths](https://github.com/Mayhorovitz/city_paths/blob/main/docs/city%20paths.jpg)

---

# Problem

Many people feel unsafe in urban spaces, especially at night or in unfamiliar areas.

# Solution

City Paths computes multiple routes and assigns each a Safety Score based on lighting density, nearby open venues, historical incidents, and live community reports. Users contribute structured reports and post trip feedback that continuously improves the model.

---

## Features

- **Safe Route Calculation**: Multiple route alternatives with safety scoring
- **Dynamic Safety Analysis**: Real-time scoring based on lighting, businesses, crime data, and user reports
- **Community Reports**: Users can report hazards, poor lighting, suspicious activity, and security presence
- **Reputation System**: User credibility scoring based on report accuracy and community feedback
- **Route Feedback**: Post-navigation safety ratings to improve future recommendations

---

## Tech Stack

- **Mobile App**: Flutter (Dart) with Google Maps integration
- **Backend**: Node.js + Express
- **Database**: PostgreSQL with PostGIS for geospatial queries
- **ML Service**: Python FastAPI for route safety prediction
- **Maps & Navigation**: Google Maps API
- **Cloud Hosting**: AWS EC2
- **Deployment Tools**: PM2, PostgreSQL CLI, SCP, SSH

---

## Project Structure

```
city_paths/
├── backend/    # Node.js Express server
├── mobile/     # Flutter mobile application
├── ml_service/ # Python ML prediction service
└── docs/       # Project documentation
```

---

## API Documentation

## Postman Collection

Import the collection: [City Paths API Collection](./docs/city_paths_collection.json)

**Quick Start:**

1. Import the collection to Postman
2. Run "Login User" request
3. Token will be saved automatically
4. All other requests will use the saved token

## Testing

Run automated tests: `npm test` (backend)

---

## Installation & Setup

### Prerequisites

- [Node.js](https://nodejs.org/) 18+
- [PostgreSQL](https://www.postgresql.org/) 15+ with PostGIS
- [Python](https://www.python.org/) 3.9+
- [Flutter](https://flutter.dev/) 3.0+

---

### Clone the repository

```bash
git clone https://github.com/mayhorovitz/city_paths.git
cd city_paths
```

---

### Backend Setup

#### Database Setup

```bash
createdb city_paths
psql city_paths -c "CREATE EXTENSION postgis;"
```

#### Backend Installation

```bash
cd backend
npm install

# Create environment config
cp .env.example .env
```

---

### ML Service Setup

```bash
cd ml_service
pip install -r requirements.txt

# Create environment config
cp .env.example .env
# Run the ML server
python main.py
```

---

### Mobile App Setup

```bash
cd mobile
flutter pub get
flutter run

# Create environment config
cp .env.example .env
```

---

## Documentation

- All project documents are available in the [docs](./docs) folder.
- Backend code is located in the [backend](./backend) folder.
- Mobile app source code is in the [mobile](./mobile) folder.
- ML service implementation in the [ml_service](./ml_service).
