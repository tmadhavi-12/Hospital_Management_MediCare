# MediCare Connect - Hospital Management (Flutter)

## Run
    flutter create .        # first time only
    flutter pub get
    flutter run -d chrome --web-port=5000     # keep the same port so saved data stays

## Three kinds of login
| Who | How to login | What they can do |
|---|---|---|
| **Patient** | Register / login with phone + password | Pick a hospital, see its doctors, book appointments, ambulance + blood requests, health card, alerts |
| **Hospital management** | Hospital login ID + password (given by admin). Demo: `citycare`, `sunrise`, `lifeline` / password `hospital123` | ONLY their own hospital: **confirm / decline appointments**, doctors, ambulances, blood bank, hospital profile, alerts |
| **Admin** | PIN `1234` | ONLY **add hospitals** + create / reset their login. No access to appointments, doctors or patients |

## Alerts
* Patient books -> **hospital gets an alert**.
* Hospital confirms / declines / completes -> **patient gets an alert**.
* Patient requests ambulance or blood -> **hospital gets an EMERGENCY alert**; when the hospital dispatches / fulfils -> patient gets an alert.
* Alerts show as a bell with a count, a pop-up right after login, and a banner while the app is open.
* Hospital can also message the patient on WhatsApp from each appointment.

## Database
Local Hive database (Chrome + mobile). Tables: users, hospitals, doctors, appointments, ambulances,
ambulanceRequests, bloodRequests, donors, bloodStock, notifications, meta.
Passwords (patients + hospitals) are stored as salted SHA-256 hashes.
