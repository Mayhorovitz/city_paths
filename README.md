# City Paths

**City Paths** **City Paths** is a community-powered safety navigation app that helps people move through cities more safely by suggesting routes optimized for street lighting, open businesses, crime data, and real-time user reports.

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

## Installation & Setup

## Documentation

- All project documents are available in the [docs](./docs) folder.
- Backend code is located in the [backend](./backend) folder.
- Mobile app source code is in the [mobile](./mobile) folder.
