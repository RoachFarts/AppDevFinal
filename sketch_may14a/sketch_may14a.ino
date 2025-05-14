// Include necessary libraries
#include <WiFi.h>
#include <WebServer.h>     // For creating a simple web server
#include <Adafruit_AHTX0.h>
#include <ArduinoJson.h>   // For creating JSON responses

// ********************************************************************
// IMPORTANT: Replace with your actual home network credentials
// ********************************************************************
const char* ssid = "PLDTHOMEFIBR05788";
const char* password = "PLDTWIFIh5zs5";
// ********************************************************************

// --- AHT20 Temperature and Humidity Sensor ---
Adafruit_AHTX0 aht;
bool aht20Found = false;

// --- HC-SR04 Ultrasonic Sensor Pin Definitions ---
const int trigPin = 5;  // ESP32 GPIO pin connected to HC-SR04 Trig
const int echoPin = 18; // ESP32 GPIO pin connected to HC-SR04 Echo
                        // REMEMBER: If HC-SR04 is powered by 5V, use a voltage divider for the Echo pin!
const float SOUND_SPEED = 0.0343; // Speed of sound in cm/microsecond (approx. at 20°C)

// --- MQ-137 Gas Sensor Pin Definition ---
// const int mq137AoutPin = 34; // ESP32 ADC1_CH6 (GPIO34) - No longer used for primary reading
const int mq137DoutPin = 35;   // ESP32 GPIO pin for MQ-137 Digital Output (DOUT)
                               // Choose any suitable digital GPIO pin. GPIO35 is an input-only pin.
                               // REMEMBER: DOUT voltage level. If it's 5V, use a voltage divider or ensure your module outputs 3.3V.

// Create a WebServer object on port 80
WebServer server(80);

// Global variables to store sensor readings
float currentTemperature = 0.0;
float currentHumidity = 0.0;
long currentDistance = 0;
int mq137DigitalValue = 0; // Digital value from MQ-137 (0 or 1)

// Function to read distance from HC-SR04
long readDistance() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  long duration = pulseIn(echoPin, HIGH, 30000); // Timeout after 30ms
  if (duration > 0) {
    long distance = (duration * SOUND_SPEED) / 2;
    return distance;
  }
  return -1; // Error or out of range
}

// Function to read digital value from MQ-137 DOUT pin
int readMq137Digital() {
  return digitalRead(mq137DoutPin); // Reads HIGH (1) or LOW (0)
}

// Function to handle the root ('/') request
void handleRoot() {
  String html = "<html><head><title>ESP32 Sensor Hub</title></head><body>";
  html += "<h1>ESP32 Multi-Sensor Hub (Home Network)</h1>";
  html += "<p><strong>Device IP:</strong> " + WiFi.localIP().toString() + "</p>";
  html += "<p><strong>Connected to Wi-Fi:</strong> " + String(ssid) + "</p>";
  html += "<h2>Sensor Status:</h2>";
  html += "<p>AHT20 Temp/Humidity: " + String(aht20Found ? "Found" : "NOT FOUND - Check Wiring!") + "</p>";
  html += "<p>HC-SR04 Distance: Active</p>";
  html += "<p>MQ-137 Gas Sensor (Digital): Active. <strong style='color:orange;'>Adjust potentiometer on module for threshold. Allow preheating.</strong></p>";
  html += "<p>Access <strong>/data</strong> to get sensor readings in JSON format.</p>";
  html += "</body></html>";
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/html", html);
}

// Function to handle the '/data' request and send sensor readings as JSON
void handleSensorData() {
  StaticJsonDocument<512> jsonDocument; // Size should still be sufficient

  // Read AHT20 sensor data
  if (aht20Found) {
    sensors_event_t humidity_event, temp_event;
    if (aht.getEvent(&humidity_event, &temp_event)) {
      jsonDocument["temperature"] = temp_event.temperature;
      jsonDocument["humidity"] = humidity_event.relative_humidity;
      jsonDocument["unit_temperature"] = "C";
      jsonDocument["unit_humidity"] = "%";
    } else {
      jsonDocument["temperature"] = "error_read";
      jsonDocument["humidity"] = "error_read";
      Serial.println("Failed to read from AHT20 sensor");
    }
  } else {
    jsonDocument["temperature"] = "N/A"; // AHT20 not found
    jsonDocument["humidity"] = "N/A";
  }

  // Read HC-SR04 distance data
  currentDistance = readDistance();
  if (currentDistance >= 0) {
    jsonDocument["distance"] = currentDistance;
    jsonDocument["unit_distance"] = "cm";
  } else {
    jsonDocument["distance"] = "error_range";
    jsonDocument["unit_distance"] = "cm";
    Serial.println("Failed to read from HC-SR04 or out of range.");
  }

  // Read MQ-137 digital gas sensor data
  mq137DigitalValue = readMq137Digital();
  jsonDocument["mq137_digital_state"] = mq137DigitalValue; // 0 for LOW, 1 for HIGH
  jsonDocument["mq137_interpretation"] = (mq137DigitalValue == HIGH) ? "Gas detected above threshold" : "Gas below threshold";
  // The meaning of HIGH/LOW (gas detected or not) depends on the MQ-137 module's DOUT logic
  // and potentiometer setting. Typically, DOUT goes LOW when gas is detected above the threshold.
  // You might need to invert this logic based on your specific module.
  // For example, if DOUT is LOW on detection:
  // jsonDocument["mq137_interpretation"] = (mq137DigitalValue == LOW) ? "Gas detected above threshold" : "Gas below threshold";
  server.sendHeader("Access-Control-Allow-Origin", "*");

  String jsonString;
  serializeJson(jsonDocument, jsonString);
  server.send(200, "application/json", jsonString);
}

void setup_wifi_station() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to WiFi SSID: ");
  Serial.println(ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.print("Attempting to connect");
  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 30) {
    delay(500);
    Serial.print(".");
    retries++;
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WiFi connected successfully!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Failed to connect to WiFi.");
    Serial.println("Please check your SSID and Password, and that your router is in range.");
    Serial.println("ESP32 will restart in 10 seconds to try again...");
    delay(10000);
    ESP.restart();
  }
}

void setup() {
  Serial.begin(115200);
  while (!Serial) {
    delay(10);
  }
  Serial.println("ESP32 Multi-Sensor (AHT20, HC-SR04, MQ-137 Digital) Web Server Starting...");
  Serial.println("-----------------------------------------------------------------");
  Serial.println("MQ-137 Sensor (Digital DOUT): Remember to allow sufficient preheating time!");
  Serial.println("MQ-137 Sensor (Digital DOUT): Adjust potentiometer on module to set detection threshold.");
  Serial.println("MQ-137 Sensor (Digital DOUT): If DOUT is 5V, ensure a voltage divider or level shifter is used.");
  Serial.println("-----------------------------------------------------------------");


  // Initialize AHT20 sensor
  if (!aht.begin()) {
    Serial.println("Could not find AHT20? Check wiring!");
    aht20Found = false;
  } else {
    Serial.println("AHT20 Found!");
    aht20Found = true;
  }

  // Initialize HC-SR04 pins
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  Serial.println("HC-SR04 Pins Initialized.");

  // Initialize MQ-137 Digital Pin
  pinMode(mq137DoutPin, INPUT); // Set DOUT pin as input
  Serial.println("MQ-137 Digital Pin (DOUT) Initialized.");


  // Setup Wi-Fi
  setup_wifi_station();

  if (WiFi.status() == WL_CONNECTED) {
    server.on("/", HTTP_GET, handleRoot);
    server.on("/data", HTTP_GET, handleSensorData);
    server.begin();
    Serial.println("HTTP server started.");
    Serial.print("Open your browser and navigate to http://");
    Serial.print(WiFi.localIP());
    Serial.println("/");
  } else {
    Serial.println("HTTP server not started due to WiFi connection failure.");
  }
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    server.handleClient();
  }
  delay(10);
}
