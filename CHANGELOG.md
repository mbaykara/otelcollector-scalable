# Changelog

All notable changes to the OpenTelemetry Collector Scalable Chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Stateful Components Configuration**: Updated `spanmetrics` and `servicegraph` collectors to use `statefulset` mode for proper trace aggregation
- **Comprehensive Loadbalancing Resiliency**: 
  - Dual-level retry mechanisms (loadbalancing and OTLP levels)
  - Persistent queuing with file storage extension
  - Timeout configurations optimized for Kubernetes environments
  - Consistent hashing for deterministic routing
- **File Storage Extension**: Added persistent storage support for loadbalancing queues
- **Volume Management**: Added persistent volume mounts for queue storage
- **Enhanced NOTES Template**: Updated deployment notes to show stateful collector indicators
- **Critical Validation System**:
  - Template validation for required fields and configuration consistency
  - Pre-install validation hooks to check dependencies and prerequisites
  - Health checks and probes for automatic recovery
  - Mode enforcement validation for stateful components
  - Post-deployment validation tests

### Changed
- **Collector Modes**:
  - `spanmetrics`: Changed from `deployment` to `statefulset`
  - `servicegraph`: Changed from `deployment` to `statefulset`
- **Loadbalancing Configuration**:
  - Enhanced timeout settings (10s loadbalancing, 1s OTLP)
  - Improved retry strategies with exponential backoff
  - Added persistent queuing with 1000 item capacity and 2 consumers
- **Service Extensions**: Updated to include file storage extension for receiver collectors
- **Documentation**: Fixed NOTES.txt table formatting and alignment issues

### Fixed
- **Table Alignment**: Corrected OTLP endpoints table formatting in deployment notes
- **Volume Mounts**: Properly configured storage volumes for persistent queuing

### Technical Details
- **Routing Keys**: Maintained optimal routing strategies
  - `tailsampling`: `traceID` (ensures complete traces)
  - `spanmetrics`: `service` (service-based distribution)
  - `servicegraph`: `traceID` (complete trace visibility)
- **Resiliency Settings**:
  - Loadbalancing level: 5-300s retry window for elastic environments
  - OTLP level: Default settings for temporary backend issues
  - Queue persistence: Survives pod restarts and scale events

### Migration Notes
- Existing deployments will need manual deletion of old Deployment resources when upgrading to StatefulSet mode
- File storage requires appropriate volume permissions in the Kubernetes cluster
- Consider backup strategies for persistent queue data in production environments