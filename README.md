# CustomQGC
# CustomQGC for Advanced Tunnel Inspection ROV Capabilities

## Overview

The CustomQGC (Custom Ground Control) application enhances the functionality of Remotely Operated Vehicles (ROVs) used for tunnel inspection. This application implements a centering algorithm and obstacle avoidance using an array of eight altimeter echosounder sensors. The data from these sensors is processed using a Kalman filter algorithm to ensure accuracy and reliability.

## Key Features

- **Centering Algorithm**: Enables the ROV to maintain its position at the center of the tunnel, adjusting its movements in real-time based on sensor input.
- **Obstacle Avoidance**: Continuously scans for obstacles, allowing the ROV to navigate safely and efficiently through the tunnel environment.
- **Active Yaw Control**: Maintains the ROV's orientation, ensuring it faces the desired direction during inspection.
- **Offset Distance Maintain**: Keeps the ROV at a specified distance from the tunnel walls, improving inspection precision.
- **Horizontal or Vertical Centering**: Provides options for centering the ROV either horizontally or vertically within the tunnel.
- **External INS Fusion**: Integrates data from an external Inertial Navigation System (INS) for enhanced positioning accuracy.


## Technical Details

- **Sensor Array**: The ROV is equipped with eight altimeter echosounder sensors, providing comprehensive environmental data.
- **Kalman Filter**: Processes the sensor data to reduce noise and improve measurement accuracy, ensuring precise control of the ROV's movements.
- **Middleware Integration**: Streams the altimeter data to QGC via a UDP port, enabling seamless communication and data exchange between the ROV and the control system.

## Middleware Streaming

The middleware plays a crucial role by collecting data from the altimeter sensors and transmitting it to the CustomQGC application through a UDP port. This setup ensures that the control system receives real-time data, which is essential for the timely execution of the centering algorithm and obstacle avoidance maneuvers.

**Note**: The middleware component responsible for streaming altimeter data is not included in this repository. Users will need to implement or source this middleware separately to enable the full functionality of the CustomQGC application.




<p align="center">
  <img src="CustomQGC.PNG">
</p>
