# 05_DATA_MODELS.md

> Tapper — Canonical Data Model Specification
Version 1.0
Status: Engineering Specification

---

# 1. Purpose

## 1.1 Objective

This document defines the canonical data model specification for the Tapper Recognition System.

It serves as the authoritative reference for every data structure exchanged between the subsystems of Tapper, ensuring that all components operate using a consistent, deterministic, and versioned representation of information.

Unlike the Algorithm Specification, which defines **how recognition operates**, this document defines **what information exists**, **how it is represented**, **how it flows through the system**, and **how it is stored**.

This specification establishes a shared contract between all runtime components and serves as the foundation for implementation, testing, persistence, diagnostics, and future system evolution.

---

## 1.2 Goals

The primary goals of this specification are to:

- Define every canonical data structure used by the Tapper system.
- Eliminate ambiguity in data representation across subsystems.
- Ensure deterministic interpretation of recognition data.
- Establish a single source of truth for all runtime objects.
- Support serialization, persistence, and version compatibility.
- Facilitate modular software architecture.
- Enable consistent implementation across development teams.

---

## 1.3 Intended Audience

This document is intended for:

- Software Engineers
- DSP Engineers
- Systems Architects
- QA Engineers
- Future Contributors
- Documentation Maintainers

Readers are expected to have a working knowledge of software engineering principles, object-oriented design, and basic digital signal processing concepts.

---

## 1.4 Relationship to Other Specifications

This document complements, but does not replace, the other engineering specifications within the Tapper project.

In particular:

- **04_ALGORITHM.md** defines the deterministic recognition pipeline and mathematical foundations.
- **05_DATA_MODELS.md** defines the objects exchanged throughout that pipeline.
- Future specifications (Audio Engine, Calibration Engine, Storage, Testing, etc.) shall reference the models defined herein rather than introducing alternative representations.

No implementation document shall redefine any data model specified in this document.

---

## 1.5 Scope of the Specification

This specification defines:

- Primitive data types
- Enumerations
- Runtime objects
- Statistical models
- Calibration models
- Recognition models
- Persistence models
- Diagnostics models
- Object relationships
- Serialization requirements
- Validation rules
- Version compatibility
- Memory ownership expectations

This specification does **not** define:

- Recognition algorithms
- Digital signal processing techniques
- User interface design
- Audio hardware configuration
- Command execution logic

Those subjects are covered in their respective specifications.

---

## 1.6 Canonical Representation

Every logical entity within the Tapper system shall have exactly one canonical data model.

Examples include:

- FeatureVector
- CalibrationProfile
- RecognitionResult
- ZoneProfile
- Candidate
- AudioBuffer

Alternative or duplicate representations of the same conceptual entity shall not exist within the codebase.

This guarantees consistency between runtime processing, persistence, diagnostics, and testing.

---

## 1.7 Deterministic Data Modeling

All data structures defined in this specification shall satisfy the following properties:

- Deterministic representation
- Immutable where practical
- Explicit ownership
- Well-defined lifecycle
- Strong typing
- Version awareness
- Serialization compatibility

The same logical state shall always produce the same serialized representation.

---

## 1.8 Engineering Objectives

The data model architecture has been designed to achieve the following engineering objectives:

- Simplicity
- Predictability
- Type safety
- Runtime efficiency
- Memory efficiency
- Thread safety
- Maintainability
- Extensibility

Every model should have a clearly defined responsibility and minimal coupling with unrelated components.

---

## 1.9 Document Conventions

Throughout this specification:

- **Model** refers to a structured representation of data.
- **Field** refers to an individual property within a model.
- **Immutable** indicates that a model shall not be modified after construction.
- **Mutable** indicates controlled modification is permitted.
- **Canonical** denotes the single authoritative representation of a concept.
- **Persistent** refers to data that survives application termination.
- **Transient** refers to runtime-only data.

Normative keywords such as **shall**, **should**, and **may** are interpreted according to RFC 2119.

---

## 1.10 Summary

This document establishes the canonical data model architecture for the Tapper Recognition System.

By defining every runtime object, statistical model, calibration artifact, diagnostic record, and persistence structure within a unified specification, it ensures that every subsystem communicates through a consistent, deterministic, and versioned representation of data.

The following section defines the scope of the data model architecture and identifies the boundaries of this specification.

# 2. Data Model Architecture

## 2.1 Overview

The Tapper Recognition System consists of multiple independent subsystems that communicate exclusively through well-defined data models.

Each subsystem owns specific models and exchanges immutable objects with other components through explicit interfaces. This architecture minimizes coupling, improves maintainability, and ensures deterministic behavior throughout the recognition pipeline.

The data model architecture serves as the common language of the entire application.

---

## 2.2 Architectural Principles

The data model architecture has been designed according to the following principles:

- Single Source of Truth
- Strong Typing
- Immutability by Default
- Explicit Ownership
- Deterministic State Representation
- Minimal Coupling
- Version Awareness
- Serialization Compatibility

Every model shall have a clearly defined responsibility and lifecycle.

---

## 2.3 Layered Architecture

The data models are organized into logical layers corresponding to the processing stages of the recognition engine.

```

Application Layer

↓

Command Models

↓

Recognition Models

↓

Statistical Models

↓

Feature Models

↓

DSP Models

↓

Audio Models

↓

Hardware

```

Each layer depends only on the layer directly beneath it.

Lower layers shall never reference higher-level models.

---

## 2.4 Data Flow

During runtime, data progresses through the following sequence:

```

Raw Audio

↓

AudioBuffer

↓

AudioFrame

↓

Window

↓

FFTResult

↓

Spectrum

↓

FeatureVector

↓

Candidate

↓

RecognitionResult

↓

Command

↓

Application Action

```

Each transformation produces a new model without modifying the previous one.

This immutable pipeline improves reproducibility, debugging, and thread safety.

---

## 2.5 Model Categories

All data models belong to one of the following categories.

### Audio Models

Represent raw microphone data and associated metadata.

Examples:

- AudioBuffer
- AudioFrame
- AudioMetadata

---

### DSP Models

Represent intermediate signal processing artifacts.

Examples:

- Window
- FFTResult
- Spectrum

---

### Feature Models

Represent extracted acoustic characteristics.

Examples:

- Feature
- FeatureVector
- FeatureStatistics

---

### Calibration Models

Represent calibration data collected from the user.

Examples:

- CalibrationSample
- ZoneCalibration
- CalibrationProfile

---

### Statistical Models

Represent mathematical objects used by the classifier.

Examples:

- MeanVector
- CovarianceMatrix
- ThresholdModel

---

### Recognition Models

Represent runtime recognition results.

Examples:

- Candidate
- ClassificationResult
- RecognitionResult

---

### Runtime Models

Represent the operational state of the engine.

Examples:

- RuntimeState
- RuntimeConfiguration
- EngineStatus

---

### Diagnostics Models

Represent logs, metrics, and debugging information.

Examples:

- DiagnosticsRecord
- PerformanceMetrics
- RecognitionLog

---

### Command Models

Represent actions executed after successful recognition.

Examples:

- Command
- Action
- ZoneMapping

---

### Persistence Models

Represent data written to or read from permanent storage.

Examples:

- StoredProfile
- FileVersion
- MigrationInfo

---

## 2.6 Ownership Model

Every data model shall have a single owning subsystem.

Ownership defines:

- Creation
- Validation
- Mutation
- Destruction
- Persistence

No model shall have multiple owners simultaneously.

Subsystems may consume models they do not own but shall not modify them unless explicitly permitted by this specification.

---

## 2.7 Mutability

The Tapper architecture follows an immutable-first design philosophy.

Models are classified as either:

### Immutable

Constructed once and never modified.

Examples:

- FeatureVector
- FFTResult
- RecognitionResult
- CalibrationProfile

---

### Controlled Mutable

Modified only by their owning subsystem.

Examples:

- RuntimeConfiguration
- EngineStatus
- RecognitionSession

Mutable models shall expose only well-defined update mechanisms.

---

## 2.8 Object Identity

Each model shall have a clearly defined identity.

Objects are categorized as:

### Value Objects

Defined entirely by their contents.

Examples:

- FeatureVector
- Spectrum
- MeanVector

Two value objects with identical contents are considered equal.

---

### Entity Objects

Defined by a persistent identity.

Examples:

- CalibrationProfile
- RecognitionSession
- StoredProfile

Entity objects remain distinct even if their contents temporarily match.

---

## 2.9 Dependency Rules

Data models shall follow these dependency constraints:

- Lower-level models shall not depend on higher-level models.
- Runtime models shall not reference UI components.
- Statistical models shall remain independent of persistence.
- Audio models shall not contain recognition state.
- Feature models shall not contain command information.

These constraints preserve modularity and reduce architectural coupling.

---

## 2.10 Summary

The Tapper data model architecture organizes the system into well-defined layers connected through immutable, strongly typed models.

By enforcing explicit ownership, controlled dependencies, and deterministic data flow, the architecture provides a stable foundation for every subsystem while supporting maintainability, extensibility, and long-term compatibility.

The following section defines the primitive data types and enumerations upon which all subsequent models are built.

# 3. Primitive Data Types and Enumerations

## 3.1 Overview

This section defines the primitive data types and enumerations used throughout the Tapper Recognition System.

These definitions form the foundation upon which every higher-level model is constructed. All runtime objects, statistical models, calibration artifacts, and persistence structures shall use the types defined herein.

Implementations claiming compliance with this specification shall not substitute alternative primitive representations without explicit justification.

---

# 3.2 Primitive Data Types

The following primitive types constitute the canonical representation of all data within the recognition engine.

| Type | Purpose |
|------|---------|
| Bool | Logical values |
| Int | Integer values |
| UInt | Unsigned integer values |
| Double | Floating-point numerical calculations |
| Float | Optional performance-critical DSP operations |
| String | Human-readable text |
| UUID | Unique identifiers |
| Date | Absolute timestamps |
| TimeInterval | Relative durations |
| Data | Binary data |
| URL | File system references |

Unless otherwise specified, all numerical calculations shall use **Double (64-bit IEEE-754 floating-point)**.

---

## 3.3 Numerical Precision

Numerical precision is critical to deterministic statistical recognition.

The following precision rules apply:

| Data | Precision |
|------|-----------|
| Feature Values | Double |
| FFT Magnitudes | Double |
| Mean Vector | Double |
| Covariance Matrix | Double |
| Mahalanobis Distance | Double |
| Confidence Score | Double |

Float32 may be used internally by platform DSP libraries where appropriate, provided the canonical data model stores values as Double.

---

## 3.4 Time Representation

The recognition engine distinguishes between absolute time and elapsed time.

### Absolute Time

Represents a unique point in time.

Examples:

- Recognition timestamp
- Calibration timestamp
- Diagnostics timestamp

Canonical Type:

```
Date
```

---

### Relative Time

Represents elapsed duration.

Examples:

- Attack Time
- Decay Time
- Signal Duration
- Cooldown
- Processing Latency

Canonical Type:

```
TimeInterval
```

Unless otherwise stated, durations are measured in seconds.

---

## 3.5 Identifiers

Persistent objects shall possess globally unique identifiers.

Canonical type:

```
UUID
```

Examples include:

- CalibrationProfile
- RecognitionSession
- DiagnosticsRecord
- StoredProfile

Transient runtime objects are not required to possess UUIDs unless explicitly specified.

---

## 3.6 Collections

Only the following collection types shall be used.

| Collection | Usage |
|------------|------|
| Array | Ordered collections |
| Dictionary | Key-value lookup |
| Set | Unique unordered values |

Arrays shall preserve insertion order.

Sets shall not be used where deterministic ordering is required.

---

## 3.7 Optional Values

Optional values represent information that may legitimately be absent.

Examples include:

- Optional diagnostics
- Optional metadata
- Optional calibration notes

Optional values shall not be used to represent invalid runtime states.

Missing required data shall instead result in validation failure.

---

# 3.8 Enumerations

Enumerations define finite sets of valid values.

Implementations shall reject undefined enumeration values.

Enumerations shall remain version compatible wherever practical.

---

## 3.9 InteractionZone

Represents the physical region of the laptop chassis associated with a tap.

```
enum InteractionZone {

    case topLeft

    case topRight

    case bottomLeft

    case bottomRight

    case unknown

}
```

The `unknown` value indicates that no valid classification could be produced.

---

## 3.10 RecognitionStatus

Represents the outcome of a recognition attempt.

```
enum RecognitionStatus {

    case success

    case rejected

    case ambiguous

    case unknown

    case cooldown

    case error

}
```

This enumeration shall be used throughout runtime recognition.

---

## 3.11 CandidateStatus

Represents the lifecycle of an acoustic candidate.

```
enum CandidateStatus {

    case detected

    case validated

    case rejected

    case classified

}
```

Candidates progress sequentially through these states.

---

## 3.12 RuntimeState

Represents the current operational state of the recognition engine.

```
enum RuntimeState {

    case idle

    case listening

    case processing

    case cooldown

    case calibrating

    case error

}
```

This enumeration corresponds directly to the Runtime State Machine defined in `04_ALGORITHM.md`.

---

## 3.13 CalibrationStatus

Represents the current state of the calibration process.

```
enum CalibrationStatus {

    case notStarted

    case inProgress

    case validating

    case completed

    case failed

}
```

---

## 3.14 QualityRating

Represents the overall quality of a tap or calibration sample.

```
enum QualityRating {

    case excellent

    case good

    case acceptable

    case poor

    case invalid

}
```

This rating is intended for diagnostics and user feedback.

It shall not directly influence statistical classification.

---

## 3.15 LogLevel

Defines diagnostic logging severity.

```
enum LogLevel {

    case debug

    case info

    case warning

    case error

    case critical

}
```

---

## 3.16 CommandType

Represents the category of action executed after successful recognition.

```
enum CommandType {

    case keyboardShortcut

    case shellCommand

    case appleScript

    case shortcut

    case application

    case custom

}
```

Additional command types may be introduced in future versions.

---

## 3.17 PersistenceState

Represents the storage state of persistent objects.

```
enum PersistenceState {

    case transient

    case pendingSave

    case persisted

    case migrated

}
```

---

## 3.18 SerializationFormat

Represents supported serialization formats.

```
enum SerializationFormat {

    case json

    case binary

}
```

Version 1 uses JSON for all persistent storage.

Binary serialization is reserved for future implementations.

---

## 3.19 Design Guidelines

All primitive types and enumerations shall satisfy the following requirements:

- Strongly typed
- Self-descriptive
- Version stable
- Platform independent
- Serialization compatible
- Deterministic

Enumeration values shall not be reordered in future versions without an explicit migration strategy.

---

## 3.20 Summary

This section establishes the fundamental primitive types and enumerations used throughout the Tapper Recognition System.

These definitions provide a consistent, strongly typed foundation for all subsequent data models while ensuring deterministic behavior, serialization compatibility, and long-term maintainability.

The following section defines the Audio Models that represent the raw acoustic information entering the recognition pipeline.

# 4. Audio Models

## 4.1 Overview

Audio Models represent the lowest level of the Tapper Recognition System.

They define the canonical representation of microphone input before any digital signal processing is performed.

These models are owned exclusively by the Audio Engine and serve as the interface between hardware acquisition and the DSP pipeline.

Audio Models shall contain only information directly related to audio capture and shall not include recognition, classification, or application-specific state.

---

## 4.2 Design Objectives

The Audio Models have been designed to satisfy the following objectives:

- Deterministic representation
- Minimal memory overhead
- High throughput
- Zero-copy processing where practical
- Thread-safe ownership
- Platform independence
- Compatibility with AVAudioEngine

The models shall support continuous real-time streaming without unnecessary allocation or duplication.

---

# 4.3 AudioBuffer

## Purpose

`AudioBuffer` represents a contiguous block of raw microphone samples captured from the audio subsystem.

It is the primary input to the DSP pipeline.

An `AudioBuffer` shall contain only raw PCM data and metadata required for processing.

---

### Canonical Structure

```swift
struct AudioBuffer {

    let id: UUID

    let samples: [Float]

    let sampleRate: Double

    let channelCount: Int

    let timestamp: Date

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| id | UUID | Unique buffer identifier |
| samples | Array<Float> | Raw PCM samples |
| sampleRate | Double | Sampling frequency |
| channelCount | Int | Number of channels |
| timestamp | Date | Capture timestamp |

---

### Ownership

Owned by:

- Audio Engine

Consumed by:

- DSP Engine

Destroyed after:

- Feature extraction completes

---

## Validation Rules

A valid AudioBuffer shall satisfy:

- Sample count > 0
- Sample rate > 0
- Channel count ≥ 1
- Timestamp valid
- Samples normalized to Float PCM

Buffers failing validation shall be discarded.

---

# 4.4 AudioFrame

## Purpose

An AudioFrame represents a fixed processing segment extracted from an AudioBuffer.

Unlike AudioBuffer, which may contain arbitrary lengths of captured audio, AudioFrame represents the exact analysis window consumed by the DSP pipeline.

---

### Canonical Structure

```swift
struct AudioFrame {

    let samples: [Float]

    let frameSize: Int

    let timestamp: Date

}
```

---

### Responsibilities

AudioFrame shall:

- represent one processing window
- remain immutable
- preserve chronological ordering
- provide deterministic input for DSP

---

### Lifetime

Created by:

Audio Engine

Consumed by:

Signal Preprocessing

Destroyed after:

Window processing completes.

---

# 4.5 AudioMetadata

## Purpose

AudioMetadata stores descriptive information about the audio acquisition environment.

Unlike AudioBuffer, it contains no audio samples.

---

### Canonical Structure

```swift
struct AudioMetadata {

    let inputDevice: String

    let sampleRate: Double

    let channelCount: Int

    let bitDepth: Int

    let captureTimestamp: Date

}
```

---

### Usage

AudioMetadata supports:

- diagnostics
- calibration reports
- debugging
- compatibility verification

It shall not participate in recognition decisions.

---

# 4.6 Audio Stream

Audio is represented as an ordered sequence of AudioBuffers.

```
Microphone

↓

AudioBuffer

↓

AudioFrame

↓

DSP Pipeline
```

The ordering of buffers shall be preserved throughout processing.

No buffer reordering is permitted.

---

# 4.7 Sample Representation

Raw samples shall satisfy the following requirements.

| Property | Requirement |
|-----------|-------------|
| Encoding | PCM Float |
| Range | [-1.0, 1.0] |
| Precision | Float32 |
| Endianness | Native Platform |
| Channels | Mono |

Samples shall not contain compressed or encoded audio.

---

# 4.8 Buffer Ownership

Ownership of audio data transitions as follows.

```
AVAudioEngine

↓

Audio Engine

↓

AudioBuffer

↓

DSP Engine

↓

Released
```

Only one subsystem shall own mutable access at any time.

Consumers shall treat received buffers as immutable.

---

# 4.9 Memory Management

Audio processing is performance-critical.

Implementations should:

- reuse buffer allocations where practical
- minimize heap allocations
- avoid unnecessary copies
- support zero-copy processing
- release buffers immediately after processing

Real-time processing shall take precedence over allocation convenience.

---

# 4.10 Thread Safety

Audio Models are produced on the real-time audio thread.

Consumers may process them on dedicated DSP threads.

Accordingly:

- AudioBuffer instances shall be immutable.
- AudioFrame instances shall be immutable.
- Metadata shall not be modified after creation.

No shared mutable audio state shall exist.

---

# 4.11 Serialization

Audio Models are transient runtime objects.

They shall not normally be serialized or persisted.

Exceptions include:

- diagnostic recording
- debugging
- performance benchmarking

Raw microphone recordings shall never be stored without explicit user authorization.

---

# 4.12 Lifecycle

The lifecycle of an AudioBuffer is illustrated below.

```
Capture

↓

Validation

↓

AudioBuffer

↓

Frame Generation

↓

DSP Processing

↓

Released
```

The lifetime of audio objects should be as short as possible to minimize memory usage.

---

# 4.13 Design Constraints

Audio Models shall remain independent of:

- Feature Extraction
- Statistical Classification
- Calibration
- Command Execution
- User Interface

Their sole responsibility is to represent captured audio accurately and efficiently.

---

# 4.14 Summary

The Audio Models provide the deterministic foundation of the Tapper Recognition System by representing raw microphone input in a consistent, immutable, and performance-oriented manner.

By separating raw acquisition from higher-level recognition logic, these models ensure clear subsystem boundaries, efficient real-time processing, and a stable interface for the DSP pipeline.

The following section introduces the DSP Models, which represent the intermediate signal processing artifacts generated from these audio models prior to feature extraction.

# 5. DSP Models

## 5.1 Overview

DSP (Digital Signal Processing) Models represent the intermediate artifacts produced during the transformation of raw audio into a canonical Feature Vector.

Unlike Audio Models, which represent captured microphone data, DSP Models exist solely within the signal processing pipeline. They encapsulate the results of filtering, windowing, frequency-domain transformation, and spectral analysis.

DSP Models are transient, immutable, and shall exist only for the duration of a single recognition cycle.

---

## 5.2 Design Objectives

The DSP Models have been designed to achieve the following objectives:

- Represent intermediate processing stages explicitly
- Preserve deterministic execution
- Prevent loss of processing information
- Minimize memory overhead
- Support modular DSP implementations
- Enable diagnostics and debugging
- Remain independent of statistical classification

Each DSP model represents a distinct processing stage and shall not assume responsibilities belonging to other stages.

---

# 5.3 Processing Pipeline

DSP Models are created sequentially throughout the recognition pipeline.

```
AudioFrame

↓

Window

↓

Filtered Signal

↓

FFTResult

↓

Spectrum

↓

Feature Extraction
```

Each stage produces a new immutable object.

No stage shall modify the output of a previous stage.

---

# 5.4 Window

## Purpose

The `Window` model represents a windowed audio segment immediately before frequency-domain transformation.

Windowing reduces spectral leakage and prepares the signal for FFT computation.

---

### Canonical Structure

```swift
struct Window {

    let samples: [Double]

    let windowFunction: WindowFunction

    let frameSize: Int

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| samples | Array<Double> | Windowed samples |
| windowFunction | WindowFunction | Applied window type |
| frameSize | Int | Number of samples |

---

### Design Rules

A Window shall:

- contain exactly one processing frame
- remain immutable
- preserve sample ordering
- use the canonical window function defined by the algorithm specification

---

# 5.5 WindowFunction

Represents the mathematical window applied before FFT computation.

```swift
enum WindowFunction {

    case hann

    case hamming

    case blackman

    case rectangular

}
```

For Version 1, only the **Hann** window shall be used during runtime recognition.

Other values exist primarily for diagnostics, experimentation, and future compatibility.

---

# 5.6 FFTResult

## Purpose

FFTResult represents the direct output of the Fast Fourier Transform.

It contains the frequency-domain representation of a single Window.

---

### Canonical Structure

```swift
struct FFTResult {

    let magnitudes: [Double]

    let binCount: Int

    let frequencyResolution: Double

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| magnitudes | Array<Double> | Magnitude spectrum |
| binCount | Int | Number of FFT bins |
| frequencyResolution | Double | Frequency represented by each bin |

---

### Responsibilities

FFTResult shall:

- preserve spectral magnitude information
- remain immutable
- support deterministic feature extraction

Phase information is intentionally excluded from Version 1, as it is not required by the recognition algorithm.

---

# 5.7 Spectrum

## Purpose

The Spectrum model represents a processed and normalized interpretation of the FFT output.

It provides a convenient representation for spectral feature computation.

---

### Canonical Structure

```swift
struct Spectrum {

    let frequencies: [Double]

    let magnitudes: [Double]

}
```

---

### Responsibilities

Spectrum shall support computation of:

- Spectral Centroid
- Spectral Bandwidth
- Spectral Roll-off
- Dominant Frequency

It shall not perform statistical classification.

---

# 5.8 FilteredSignal

## Purpose

FilteredSignal represents audio after digital filtering but before windowing.

This intermediate representation is useful for diagnostics and feature validation.

---

### Canonical Structure

```swift
struct FilteredSignal {

    let samples: [Double]

    let highPassCutoff: Double

    let lowPassCutoff: Double

}
```

---

### Usage

FilteredSignal exists only during processing and shall not be persisted.

Implementations may omit this model internally provided equivalent functionality is maintained.

---

# 5.9 DSP Metadata

Some processing stages require additional contextual information.

```swift
struct DSPMetadata {

    let sampleRate: Double

    let fftSize: Int

    let processingTimestamp: Date

}
```

DSPMetadata provides contextual information for diagnostics and validation.

It shall not influence recognition outcomes.

---

# 5.10 Ownership

Ownership of DSP Models is defined as follows.

| Model | Owner |
|--------|-------|
| Window | DSP Engine |
| FilteredSignal | DSP Engine |
| FFTResult | DSP Engine |
| Spectrum | DSP Engine |
| DSPMetadata | DSP Engine |

No other subsystem shall modify DSP Models after creation.

---

# 5.11 Validation Rules

A valid DSP Model shall satisfy the following requirements.

### Window

- sample count equals frame size
- window function defined
- no NaN values

### FFTResult

- magnitudes non-negative
- bin count valid
- frequency resolution positive

### Spectrum

- frequency and magnitude arrays equal length
- frequencies monotonically increasing
- magnitudes non-negative

Invalid models shall be rejected before feature extraction.

---

# 5.12 Memory Management

DSP Models are short-lived runtime artifacts.

Their lifecycle is limited to a single recognition event.

```
Window

↓

FFTResult

↓

Spectrum

↓

Feature Extraction

↓

Released
```

Implementations should avoid retaining DSP Models beyond the completion of feature extraction unless diagnostics are enabled.

---

# 5.13 Thread Safety

DSP Models are immutable after construction.

This guarantees:

- safe concurrent access
- deterministic computation
- simplified synchronization
- reproducible feature extraction

No mutable DSP state shall be shared between recognition cycles.

---

# 5.14 Serialization

DSP Models are transient by design.

They shall not normally be serialized.

Serialization may be permitted for:

- debugging
- regression testing
- performance analysis
- algorithm verification

Such serialization shall be disabled in production builds by default.

---

# 5.15 Relationship to Feature Models

DSP Models exist solely to support Feature Extraction.

They are transformed into a canonical Feature Vector, after which they are no longer required.

```
Window

↓

FFTResult

↓

Spectrum

↓

FeatureVector
```

Feature Models shall never depend directly on raw audio, only on the processed representations defined in this section.

---

# 5.16 Summary

The DSP Models provide a structured, deterministic representation of the intermediate processing stages that bridge raw audio acquisition and statistical feature extraction.

By explicitly modeling windowed signals, filtered audio, frequency-domain transformations, and spectral representations, the Tapper Recognition System maintains a modular DSP architecture that is efficient, testable, and independent of higher-level recognition logic.

The following section defines the Feature Models, which represent the canonical numerical description of a tap and serve as the primary input to the statistical classification engine.
# 6. Feature Models

## 6.1 Overview

Feature Models represent the canonical numerical description of an acoustic tap.

They form the boundary between Digital Signal Processing and Statistical Classification. Every recognition decision within the Tapper Recognition System is based exclusively on Feature Models derived from the processed audio signal.

Unlike Audio Models and DSP Models, which represent intermediate processing artifacts, Feature Models capture the measurable characteristics of a tap in a compact, deterministic, and implementation-independent form.

Version 1 represents every tap using a fixed Feature Vector consisting of ten acoustic features.

---

## 6.2 Design Objectives

Feature Models have been designed to satisfy the following objectives:

- Deterministic representation
- Statistical consistency
- Hardware independence
- Compact memory footprint
- High numerical precision
- Efficient comparison
- Serialization compatibility
- Future extensibility

Every Feature Model shall represent measurable signal properties rather than implementation-specific information.

---

# 6.3 Feature

## Purpose

A Feature represents a single measurable acoustic property extracted from a processed signal.

Features are the atomic building blocks of the recognition algorithm.

Each feature describes one independent characteristic of the tap waveform or frequency spectrum.

---

### Canonical Structure

```swift
struct Feature {

    let name: FeatureType

    let value: Double

    let unit: FeatureUnit

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| name | FeatureType | Feature identifier |
| value | Double | Numerical feature value |
| unit | FeatureUnit | Physical measurement unit |

---

### Design Rules

A Feature shall:

- represent exactly one measurable quantity
- remain immutable
- store values using Double precision
- contain no statistical information

---

# 6.4 FeatureType

FeatureType identifies the acoustic property represented by a Feature.

```swift
enum FeatureType {

    case peakAmplitude

    case rmsEnergy

    case spectralCentroid

    case spectralBandwidth

    case spectralRollOff

    case dominantFrequency

    case zeroCrossingRate

    case attackTime

    case decayTime

    case signalDuration

}
```

Version 1 supports exactly ten feature types.

Future versions may extend this enumeration while preserving backward compatibility.

---

# 6.5 FeatureUnit

Each feature is associated with a physical unit.

```swift
enum FeatureUnit {

    case normalized

    case hertz

    case seconds

    case crossingsPerSecond

}
```

The unit exists primarily for diagnostics, visualization, and validation.

Recognition algorithms shall compare numerical values rather than unit labels.

---

# 6.6 FeatureVector

## Purpose

FeatureVector is the canonical numerical representation of an acoustic tap.

It aggregates all extracted features into a single immutable object used by the statistical classifier.

Every recognition decision operates exclusively on FeatureVectors.

---

### Canonical Structure

```swift
struct FeatureVector {

    let peakAmplitude: Double

    let rmsEnergy: Double

    let spectralCentroid: Double

    let spectralBandwidth: Double

    let spectralRollOff: Double

    let dominantFrequency: Double

    let zeroCrossingRate: Double

    let attackTime: Double

    let decayTime: Double

    let signalDuration: Double

}
```

---

### Canonical Ordering

The ordering of features shall remain fixed.

| Index | Feature |
|-------:|---------|
| 0 | Peak Amplitude |
| 1 | RMS Energy |
| 2 | Spectral Centroid |
| 3 | Spectral Bandwidth |
| 4 | Spectral Roll-off |
| 5 | Dominant Frequency |
| 6 | Zero Crossing Rate |
| 7 | Attack Time |
| 8 | Decay Time |
| 9 | Signal Duration |

This ordering shall remain unchanged throughout Version 1.

---

### Responsibilities

FeatureVector shall:

- represent one acoustic tap
- remain immutable
- support deterministic comparison
- serve as input to statistical classification
- support persistence within calibration profiles

It shall not contain recognition results, confidence scores, or runtime metadata.

---

# 6.7 FeatureStatistics

## Purpose

FeatureStatistics stores descriptive statistics associated with a FeatureVector population.

These statistics are primarily generated during calibration and used for diagnostics.

---

### Canonical Structure

```swift
struct FeatureStatistics {

    let minimum: Double

    let maximum: Double

    let mean: Double

    let standardDeviation: Double

}
```

---

### Responsibilities

FeatureStatistics supports:

- calibration quality analysis
- diagnostics
- statistical reporting
- visualization

It shall not replace the covariance matrix used by the classifier.

---

# 6.8 Feature Validation

Every FeatureVector shall satisfy the following validation rules.

### General

- no missing values
- no NaN values
- no infinite values
- values stored as Double

### Spectral Features

- frequencies ≥ 0 Hz
- bandwidth ≥ 0 Hz
- roll-off ≥ 0 Hz

### Temporal Features

- attack time ≥ 0
- decay time ≥ 0
- signal duration > 0

### Amplitude Features

- peak amplitude ∈ [0, 1]
- RMS energy ∈ [0, 1]

Invalid FeatureVectors shall be rejected before statistical classification.

---

# 6.9 Feature Ownership

Feature Models are owned by the Feature Extraction subsystem.

Ownership transitions occur as follows.

```
DSP Engine

↓

Feature Extraction

↓

FeatureVector

↓

Classification Engine

↓

Released
```

The Classification Engine consumes FeatureVectors but shall never modify them.

---

# 6.10 Thread Safety

Feature Models are immutable.

Once created:

- values shall never change
- no synchronization is required
- concurrent reads are safe
- deterministic comparisons are guaranteed

This allows FeatureVectors to be shared safely across processing threads.

---

# 6.11 Serialization

Feature Models shall support serialization for:

- calibration profiles
- diagnostics
- regression testing
- algorithm verification

FeatureVectors shall be serialized using Double precision to preserve numerical accuracy.

---

# 6.12 Relationship to Statistical Models

Feature Models provide the input to the statistical classifier.

```
FeatureVector

↓

Mean Vector

↓

Covariance Matrix

↓

Mahalanobis Distance

↓

Recognition Result
```

Statistical Models extend Feature Models by introducing probabilistic representations derived during calibration.

---

# 6.13 Design Constraints

Feature Models shall remain independent of:

- Audio acquisition
- DSP implementation details
- Runtime state
- User interface
- Command execution
- Persistence mechanisms

Their sole responsibility is to represent the measurable characteristics of an acoustic tap.

---

# 6.14 Summary

Feature Models define the canonical numerical representation of every tap recognized by the Tapper Recognition System.

By encapsulating the ten deterministic acoustic features within immutable, strongly typed models, they establish the interface between signal processing and statistical classification while ensuring consistency, portability, and long-term maintainability.

The following section defines the Calibration Models, which organize FeatureVectors into statistically meaningful profiles used to recognize interaction zones.
# 7. Calibration Models

## 7.1 Overview

Calibration Models represent the statistical knowledge acquired during the calibration process.

Unlike Feature Models, which describe a single tap, Calibration Models aggregate multiple Feature Vectors to construct a deterministic statistical representation of each interaction zone.

These models form the foundation of the recognition engine by defining the expected acoustic characteristics of every calibrated zone.

Calibration Models are persistent and remain valid until recalibration or migration to a newer algorithm version.

---

## 7.2 Design Objectives

Calibration Models have been designed to achieve the following objectives:

- Represent calibrated interaction zones
- Preserve statistical integrity
- Support deterministic recognition
- Enable persistent storage
- Ensure version compatibility
- Facilitate recalibration
- Maintain hardware-specific profiles

Each calibration profile shall correspond to exactly one physical device and one algorithm version.

---

# 7.3 CalibrationSample

## Purpose

A CalibrationSample represents a single validated tap collected during calibration.

It contains the extracted Feature Vector together with metadata describing the calibration context.

---

### Canonical Structure

```swift
struct CalibrationSample {

    let featureVector: FeatureVector

    let zone: InteractionZone

    let timestamp: Date

    let qualityScore: Double

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| featureVector | FeatureVector | Extracted acoustic features |
| zone | InteractionZone | Intended interaction zone |
| timestamp | Date | Time of acquisition |
| qualityScore | Double | Sample quality score |

---

### Responsibilities

CalibrationSample shall:

- represent exactly one user tap
- belong to exactly one interaction zone
- remain immutable after validation
- participate in statistical model generation

Rejected calibration attempts shall never become CalibrationSamples.

---

# 7.4 ZoneCalibration

## Purpose

ZoneCalibration represents the complete calibration dataset for a single interaction zone.

It aggregates all accepted calibration samples and the statistical model derived from them.

---

### Canonical Structure

```swift
struct ZoneCalibration {

    let zone: InteractionZone

    let samples: [CalibrationSample]

    let profile: ZoneProfile

}
```

---

### Responsibilities

ZoneCalibration shall:

- own all accepted samples for one zone
- generate statistical parameters
- support recalibration
- remain independent of other zones

Each interaction zone shall have exactly one ZoneCalibration.

---

# 7.5 ZoneProfile

## Purpose

ZoneProfile represents the finalized statistical model of a single interaction zone.

It is the object consumed by the Classification Engine during runtime.

---

### Canonical Structure

```swift
struct ZoneProfile {

    let zone: InteractionZone

    let meanVector: MeanVector

    let covarianceMatrix: CovarianceMatrix

    let threshold: Double

    let samples: [FeatureVector]

    let neighbourRadius: Double

}
```

`samples` holds every accepted Feature Vector collected for the zone during
calibration, in chronological order (ADR-015). The statistical fields above are
derived from these samples and are retained; the samples are never discarded,
because mean and covariance can be recomputed from them while the reverse is
impossible.

`neighbourRadius` is the zone's k-Nearest Neighbour acceptance radius, derived
during calibration from the leave-one-out nearest-neighbour distances within the
zone (`ALGORITHM` §17.23.7).

Profiles written before ADR-015 contain no samples. They remain valid for
Mahalanobis recognition and shall report k-Nearest Neighbour recognition as
unavailable rather than being silently loaded as complete.

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| zone | InteractionZone | Calibrated zone |
| meanVector | MeanVector | Average Feature Vector |
| covarianceMatrix | CovarianceMatrix | Statistical covariance |
| threshold | Double | Acceptance threshold |

---

### Responsibilities

ZoneProfile shall:

- represent one calibrated zone
- remain immutable
- support deterministic classification
- be persisted within CalibrationProfile

---

# 7.6 CalibrationProfile

## Purpose

CalibrationProfile is the primary persistent object generated by the calibration process.

It contains every ZoneProfile required for runtime recognition.

A Tapper installation shall maintain exactly one active CalibrationProfile for a given device.

---

### Canonical Structure

```swift
struct CalibrationProfile {

    let id: UUID

    let version: String

    let deviceIdentifier: String

    let createdAt: Date

    let zones: [ZoneProfile]

    let metadata: CalibrationMetadata

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| id | UUID | Profile identifier |
| version | String | Algorithm version |
| deviceIdentifier | String | Device fingerprint |
| createdAt | Date | Creation timestamp |
| zones | Array<ZoneProfile> | Calibrated zones |
| metadata | CalibrationMetadata | Additional information |

---

### Responsibilities

CalibrationProfile shall:

- persist statistical calibration data
- validate version compatibility
- support profile migration
- provide runtime configuration for recognition

The recognition engine shall refuse to operate without a valid CalibrationProfile.

---

# 7.7 CalibrationMetadata

## Purpose

CalibrationMetadata stores descriptive information about the calibration session.

Unlike ZoneProfile, it does not influence recognition.

---

### Canonical Structure

```swift
struct CalibrationMetadata {

    let algorithmVersion: String

    let sampleRate: Double

    let fftSize: Int

    let completedAt: Date

    let averageQuality: Double

}
```

---

### Usage

CalibrationMetadata supports:

- diagnostics
- version validation
- compatibility checking
- user information
- debugging

Recognition algorithms shall ignore this information during classification.

---

# 7.8 Calibration Session

Calibration proceeds according to the following object lifecycle.

```
CalibrationSample

↓

ZoneCalibration

↓

ZoneProfile

↓

CalibrationProfile

↓

Persistent Storage
```

Each stage builds upon the validated output of the previous stage.

---

# 7.9 Ownership

| Model | Owner |
|--------|-------|
| CalibrationSample | Calibration Engine |
| ZoneCalibration | Calibration Engine |
| ZoneProfile | Calibration Engine |
| CalibrationProfile | Storage System |
| CalibrationMetadata | Calibration Engine |

Ownership transfers to the persistence layer once calibration completes successfully.

---

# 7.10 Validation Rules

A valid CalibrationProfile shall satisfy the following requirements.

### CalibrationSample

- valid FeatureVector
- valid InteractionZone
- quality score within accepted range

### ZoneCalibration

- minimum required samples collected
- all samples belong to same zone
- no duplicate sample references

### ZoneProfile

- valid MeanVector
- positive-definite covariance matrix
- threshold computed successfully

### CalibrationProfile

- all required zones present
- algorithm version specified
- device identifier present
- metadata valid

Profiles failing validation shall not be persisted.

---

# 7.11 Thread Safety

Calibration Models are mutable only during calibration.

After successful calibration:

- ZoneProfiles become immutable
- CalibrationProfile becomes immutable
- Samples are read-only
- Statistical parameters shall never change

Any modification requires generation of a completely new CalibrationProfile.

---

# 7.12 Serialization

Calibration Models shall support deterministic serialization.

Persisted objects shall include:

- version information
- timestamps
- statistical parameters
- metadata

Serialization shall preserve numerical precision and object ordering.

---

# 7.13 Relationship to Runtime Recognition

The runtime classifier consumes ZoneProfiles directly.

```
CalibrationProfile

↓

ZoneProfile

↓

MeanVector

↓

CovarianceMatrix

↓

Classification Engine
```

No runtime learning or profile modification shall occur during recognition.

---

# 7.14 Design Constraints

Calibration Models shall remain independent of:

- User Interface
- Audio acquisition implementation
- Command execution
- Runtime state
- Diagnostics configuration

Their sole responsibility is to represent statistically valid calibration data.

---

# 7.15 Summary

Calibration Models define the persistent statistical knowledge required for deterministic recognition.

By transforming validated Feature Vectors into immutable ZoneProfiles and a versioned CalibrationProfile, they provide the Classification Engine with a stable, reproducible, and hardware-specific representation of each interaction zone while preserving compatibility across application updates.

The following section defines the Statistical Models that mathematically represent these calibration profiles and enable deterministic classification through multivariate statistical analysis.

# 8. Statistical Models

## 8.1 Overview

Statistical Models represent the mathematical foundation of the Tapper Recognition System.

They transform collections of Feature Vectors into statistical representations that enable deterministic classification of acoustic taps.

Unlike Calibration Models, which organize calibration data, Statistical Models represent the mathematical objects derived from that data. These models are consumed directly by the Classification Engine during runtime.

All statistical computations defined in this specification shall use **64-bit IEEE-754 floating-point precision (Double)**.

---

## 8.2 Design Objectives

The Statistical Models have been designed to achieve the following objectives:

- Deterministic statistical classification
- High numerical precision
- Efficient runtime evaluation
- Mathematical correctness
- Serialization compatibility
- Algorithm version independence
- Future extensibility

Statistical Models shall remain independent of the audio acquisition process and contain no application-specific logic.

---

# 8.3 MeanVector

## Purpose

The MeanVector represents the centroid of all Feature Vectors collected for a particular interaction zone during calibration.

It serves as the expected acoustic signature for that zone.

---

### Canonical Structure

```swift
struct MeanVector {

    let values: [Double]

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| values | Array<Double> | Mean value for each feature |

The ordering of values shall exactly match the canonical FeatureVector ordering defined in Section 6.

---

### Responsibilities

MeanVector shall:

- represent the statistical center of a zone
- remain immutable
- support Mahalanobis Distance computation
- contain one value for every feature

---

## Validation Rules

A valid MeanVector shall satisfy:

- exactly ten values (Version 1)
- no NaN values
- no infinite values
- canonical ordering preserved

---

# 8.4 CovarianceMatrix

## Purpose

CovarianceMatrix describes the variance and correlation between all features within an interaction zone.

It enables Mahalanobis Distance to account for natural variation in user tapping behavior.

---

### Canonical Structure

```swift
struct CovarianceMatrix {

    let values: [[Double]]

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| values | Matrix<Double> | Feature covariance matrix |

---

### Matrix Dimensions

For Version 1:

```
10 × 10
```

One row and one column correspond to each feature within the FeatureVector.

---

### Responsibilities

CovarianceMatrix shall:

- represent feature covariance
- remain immutable
- support inversion
- enable multivariate distance computation

---

## Validation Rules

A valid CovarianceMatrix shall satisfy:

- square dimensions
- symmetric
- positive definite
- invertible
- no NaN values
- no infinite values

Failure to satisfy these requirements shall invalidate the corresponding calibration profile.

---

# 8.5 InverseCovarianceMatrix

## Purpose

InverseCovarianceMatrix stores the inverse of the covariance matrix.

Its primary purpose is to eliminate repeated matrix inversion during runtime recognition.

---

### Canonical Structure

```swift
struct InverseCovarianceMatrix {

    let values: [[Double]]

}
```

---

### Responsibilities

InverseCovarianceMatrix shall:

- be computed once during calibration
- remain immutable
- accelerate Mahalanobis computation
- preserve numerical precision

It shall never be recomputed during runtime recognition.

---

# 8.6 ThresholdModel

## Purpose

ThresholdModel defines the acceptance criteria for a statistical match.

Each interaction zone possesses an independent threshold derived during calibration.

---

### Canonical Structure

```swift
struct ThresholdModel {

    let acceptanceThreshold: Double

    let ambiguityMargin: Double

}
```

---

### Responsibilities

ThresholdModel shall:

- determine recognition acceptance
- detect ambiguous classifications
- remain immutable
- support deterministic decision making

Thresholds shall not be modified after calibration.

---

# 8.7 ConfidenceModel

## Purpose

ConfidenceModel represents the diagnostic confidence associated with a recognition result.

Confidence assists user feedback and diagnostics but shall never influence classification.

---

### Canonical Structure

```swift
struct ConfidenceModel {

    let score: Double

    let rating: QualityRating

}
```

---

### Responsibilities

ConfidenceModel shall:

- provide diagnostic information
- remain independent of classification
- support visualization
- remain immutable

Recognition decisions shall be completed before confidence is computed.

---

# 8.8 StatisticalProfile

## Purpose

StatisticalProfile combines all statistical objects required to classify a single interaction zone.

---

### Canonical Structure

```swift
struct StatisticalProfile {

    let meanVector: MeanVector

    let covarianceMatrix: CovarianceMatrix

    let inverseCovarianceMatrix: InverseCovarianceMatrix

    let threshold: ThresholdModel

}
```

---

### Responsibilities

StatisticalProfile shall:

- encapsulate all mathematical parameters
- support runtime classification
- remain immutable
- belong to exactly one interaction zone

---

# 8.9 Statistical Relationships

The relationship between statistical models is illustrated below.

```
Calibration Samples

↓

Mean Vector

+

Covariance Matrix

↓

Inverse Covariance

↓

Threshold Generation

↓

StatisticalProfile

↓

Classification Engine
```

Each object is derived from validated calibration data.

---

# 8.10 Ownership

| Model | Owner |
|--------|-------|
| MeanVector | Calibration Engine |
| CovarianceMatrix | Calibration Engine |
| InverseCovarianceMatrix | Calibration Engine |
| ThresholdModel | Calibration Engine |
| ConfidenceModel | Classification Engine |
| StatisticalProfile | Calibration Engine |

During runtime, the Classification Engine receives immutable references to these models.

---

# 8.11 Thread Safety

Statistical Models are immutable.

Consequently:

- concurrent reads are safe
- synchronization is unnecessary
- recognition remains deterministic
- multiple recognition requests may share the same StatisticalProfile

No runtime mutation shall occur.

---

# 8.12 Serialization

Statistical Models shall support deterministic serialization.

Serialized representations shall preserve:

- floating-point precision
- matrix ordering
- feature ordering
- algorithm version

Implementations shall avoid lossy serialization formats.

---

# 8.13 Version Compatibility

Changes affecting:

- feature ordering
- covariance dimensions
- threshold computation
- statistical representation

shall require a new algorithm version and regeneration of all calibration profiles.

Statistical Models from different algorithm versions shall not be considered compatible.

---

# 8.14 Design Constraints

Statistical Models shall remain independent of:

- Audio Models
- DSP Models
- Runtime state
- User interface
- Storage implementation
- Command execution

Their sole responsibility is to provide the mathematical representation required for deterministic statistical classification.

---

# 8.15 Summary

Statistical Models provide the mathematical core of the Tapper Recognition System.

By representing each interaction zone through immutable Mean Vectors, Covariance Matrices, Threshold Models, and related statistical structures, they enable efficient, deterministic, and reproducible multivariate classification while maintaining strict separation from audio processing, application logic, and user interface concerns.

The following section defines the Recognition Models, which encapsulate runtime candidates, classification outcomes, and the results produced by the statistical recognition engine.

# 9. Recognition Models

## 9.1 Overview

Recognition Models represent the runtime objects produced and consumed during the recognition process.

These models encapsulate the lifecycle of an acoustic event as it progresses from initial detection to final command execution.

Unlike Calibration Models and Statistical Models, Recognition Models are transient runtime objects. They are created dynamically during recognition and destroyed once processing completes.

Recognition Models shall not contain calibration logic, DSP implementation details, or persistence responsibilities.

---

## 9.2 Design Objectives

Recognition Models have been designed to satisfy the following objectives:

- Represent runtime recognition state
- Support deterministic decision making
- Enable low-latency processing
- Facilitate diagnostics
- Minimize memory allocation
- Support future extensibility

Every Recognition Model shall correspond to a distinct stage within the recognition pipeline.

---

# 9.3 Candidate

## Purpose

A Candidate represents an acoustic event that has passed initial detection and is undergoing validation.

A Candidate is not yet recognized. It simply indicates that the signal may correspond to an intentional tap.

---

### Canonical Structure

```swift
struct Candidate {

    let id: UUID

    let featureVector: FeatureVector

    let detectedAt: Date

    let status: CandidateStatus

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| id | UUID | Unique candidate identifier |
| featureVector | FeatureVector | Extracted acoustic features |
| detectedAt | Date | Detection timestamp |
| status | CandidateStatus | Current processing state |

---

### Lifecycle

```
Detected

↓

Validated

↓

Classified

↓

Executed

↓

Released
```

Candidates rejected during validation terminate immediately and shall not proceed further through the recognition pipeline.

---

# 9.4 ClassificationResult

## Purpose

ClassificationResult represents the output produced by the statistical classifier before runtime validation.

It identifies the most probable interaction zone together with the associated statistical metrics.

---

### Canonical Structure

```swift
struct ClassificationResult {

    let zone: InteractionZone

    let distance: Double

    let confidence: ConfidenceModel

    let accepted: Bool

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| zone | InteractionZone | Best statistical match |
| distance | Double | Mahalanobis Distance |
| confidence | ConfidenceModel | Diagnostic confidence |
| accepted | Bool | Threshold evaluation result |

---

### Responsibilities

ClassificationResult shall:

- represent the output of the statistical classifier
- remain immutable
- support runtime validation
- remain independent of command execution

---

# 9.5 RecognitionResult

## Purpose

RecognitionResult represents the final outcome of a completed recognition cycle.

Unlike ClassificationResult, it reflects the complete runtime decision after threshold evaluation, ambiguity detection, cooldown handling, and validation.

---

### Canonical Structure

```swift
struct RecognitionResult {

    let status: RecognitionStatus

    let zone: InteractionZone

    let confidence: Double

    let qualityScore: Double

    let timestamp: Date

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| status | RecognitionStatus | Final recognition outcome |
| zone | InteractionZone | Recognized interaction zone |
| confidence | Double | Diagnostic confidence |
| qualityScore | Double | Tap quality score |
| timestamp | Date | Completion timestamp |

---

### Responsibilities

RecognitionResult shall:

- represent the final recognition decision
- remain immutable
- provide diagnostics
- trigger command execution when appropriate

Only RecognitionResults with a status of `.success` may initiate application actions.

---

# 9.6 RecognitionSession

## Purpose

RecognitionSession groups all Candidates and RecognitionResults produced during a continuous runtime session.

It provides context for diagnostics, benchmarking, and future analytics.

---

### Canonical Structure

```swift
struct RecognitionSession {

    let id: UUID

    let startedAt: Date

    let completedAt: Date?

    let recognitions: [RecognitionResult]

}
```

---

### Responsibilities

RecognitionSession shall:

- group runtime recognition events
- support diagnostics
- support benchmarking
- remain independent of calibration

RecognitionSession shall not influence recognition decisions.

---

# 9.7 Recognition Timeline

The lifecycle of a recognition event is illustrated below.

```
Audio Event

↓

Candidate

↓

ClassificationResult

↓

RecognitionResult

↓

Command Execution

↓

Released
```

Each object represents a higher level of abstraction than the previous stage.

---

# 9.8 Ownership

| Model | Owner |
|--------|-------|
| Candidate | Recognition Engine |
| ClassificationResult | Classification Engine |
| RecognitionResult | Recognition Engine |
| RecognitionSession | Runtime Engine |

Recognition Models shall not be modified by external subsystems.

---

# 9.9 Validation Rules

A valid Candidate shall satisfy:

- valid FeatureVector
- valid timestamp
- valid processing state

A valid ClassificationResult shall satisfy:

- valid InteractionZone
- non-negative distance
- valid confidence model

A valid RecognitionResult shall satisfy:

- valid RecognitionStatus
- timestamp present
- confidence within 0–100
- quality score within 0–100

Recognition objects failing validation shall be discarded.

---

# 9.10 Thread Safety

Recognition Models are immutable after construction.

Multiple runtime components may safely access the same RecognitionResult concurrently without synchronization.

RecognitionSession may append RecognitionResults while active, but completed RecognitionResults themselves shall never be modified.

---

# 9.11 Serialization

Recognition Models are transient by default.

Serialization is permitted for:

- diagnostics
- benchmarking
- regression testing
- recognition history

Recognition history shall not include raw microphone data.

---

# 9.12 Relationship to Other Models

Recognition Models connect Feature Models, Statistical Models, Runtime Models, and Command Models.

```
FeatureVector

↓

Candidate

↓

ClassificationResult

↓

RecognitionResult

↓

Command
```

This sequence represents the complete runtime recognition pipeline.

---

# 9.13 Design Constraints

Recognition Models shall remain independent of:

- Audio acquisition
- DSP implementation
- Calibration procedures
- Persistent storage
- User interface

Their sole responsibility is to represent the runtime state and outcome of acoustic recognition.

---

# 9.14 Summary

Recognition Models encapsulate the complete lifecycle of runtime tap recognition, from initial candidate detection to the final recognition decision.

By separating intermediate classification from final recognition outcomes and grouping events into deterministic runtime sessions, these models provide a clear, immutable representation of the recognition pipeline while supporting diagnostics, extensibility, and low-latency execution.

The following section defines the Runtime Models, which represent the operational state, configuration, and health of the Tapper Recognition Engine during execution.

# 10. Runtime Models

## 10.1 Overview

Runtime Models represent the operational state of the Tapper Recognition Engine while the application is executing.

Unlike Recognition Models, which represent individual recognition events, Runtime Models describe the state, configuration, health, and operational context of the recognition engine itself.

These models coordinate subsystem interaction, maintain runtime configuration, expose engine status, and provide deterministic control over recognition behavior.

Runtime Models shall not contain calibration data, statistical parameters, or application-specific business logic.

---

## 10.2 Design Objectives

Runtime Models have been designed to satisfy the following objectives:

- Represent engine state
- Coordinate subsystem interaction
- Support deterministic execution
- Enable runtime configuration
- Provide health monitoring
- Support diagnostics
- Minimize synchronization overhead

Runtime Models describe **how the engine is operating**, not **what it has recognized**.

---

# 10.3 RuntimeConfiguration

## Purpose

RuntimeConfiguration defines the operational settings used by the Recognition Engine during execution.

Unlike CalibrationProfile, RuntimeConfiguration contains only configurable runtime behavior and does not influence the underlying statistical model.

---

### Canonical Structure

```swift
struct RuntimeConfiguration {

    let diagnosticsEnabled: Bool

    let cooldownDuration: TimeInterval

    let recognitionEnabled: Bool

    let loggingLevel: LogLevel

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| diagnosticsEnabled | Bool | Enables runtime diagnostics |
| cooldownDuration | TimeInterval | Duplicate suppression period |
| recognitionEnabled | Bool | Enables or disables recognition |
| loggingLevel | LogLevel | Diagnostic logging level |

---

### Responsibilities

RuntimeConfiguration shall:

- configure runtime behavior
- remain independent of calibration
- support safe updates
- persist user preferences

Changing RuntimeConfiguration shall not invalidate CalibrationProfiles.

---

# 10.4 EngineStatus

## Purpose

EngineStatus represents the current health of the Recognition Engine.

It provides a snapshot of the operational readiness of all major subsystems.

---

### Canonical Structure

```swift
struct EngineStatus {

    let state: RuntimeState

    let microphoneAvailable: Bool

    let profileLoaded: Bool

    let healthy: Bool

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| state | RuntimeState | Current engine state |
| microphoneAvailable | Bool | Microphone availability |
| profileLoaded | Bool | Calibration profile loaded |
| healthy | Bool | Overall engine health |

---

### Responsibilities

EngineStatus shall:

- expose runtime readiness
- support diagnostics
- report subsystem availability
- remain immutable

---

# 10.5 RuntimeContext

## Purpose

RuntimeContext aggregates the objects required by the Recognition Engine during execution.

Unlike EngineStatus, which describes health, RuntimeContext represents the active runtime environment.

---

### Canonical Structure

```swift
struct RuntimeContext {

    let configuration: RuntimeConfiguration

    let calibrationProfile: CalibrationProfile

    let engineStatus: EngineStatus

}
```

---

### Responsibilities

RuntimeContext shall:

- provide runtime dependencies
- support subsystem coordination
- remain immutable during a recognition cycle
- simplify dependency management

---

# 10.6 RuntimeStatistics

## Purpose

RuntimeStatistics records operational metrics describing engine performance.

These statistics support diagnostics and benchmarking but shall never influence recognition decisions.

---

### Canonical Structure

```swift
struct RuntimeStatistics {

    let recognitionsProcessed: Int

    let rejectedCandidates: Int

    let averageLatency: TimeInterval

    let uptime: TimeInterval

}
```

---

### Responsibilities

RuntimeStatistics shall support:

- performance monitoring
- benchmarking
- diagnostics
- user reporting

They shall not participate in statistical classification.

---

# 10.7 Runtime Lifecycle

The Runtime Engine progresses through the following lifecycle.

```
Initialization

↓

Configuration Loaded

↓

Calibration Profile Loaded

↓

Listening

↓

Recognition

↓

Cooldown

↓

Listening

↓

Shutdown
```

Runtime Models describe the engine throughout this lifecycle.

---

# 10.8 Ownership

| Model | Owner |
|--------|-------|
| RuntimeConfiguration | Runtime Engine |
| EngineStatus | Runtime Engine |
| RuntimeContext | Runtime Engine |
| RuntimeStatistics | Runtime Engine |

No external subsystem shall directly modify these models.

---

# 10.9 Validation Rules

A valid RuntimeConfiguration shall satisfy:

- cooldown duration ≥ 0
- logging level defined
- valid Boolean values

A valid EngineStatus shall satisfy:

- valid RuntimeState
- internally consistent subsystem status

A valid RuntimeContext shall satisfy:

- configuration present
- calibration profile loaded before recognition
- engine status available

Invalid Runtime Models shall prevent recognition from starting.

---

# 10.10 Thread Safety

Runtime Models coordinate multiple concurrent subsystems.

Accordingly:

- RuntimeConfiguration updates shall be synchronized.
- EngineStatus shall be immutable once published.
- RuntimeContext shall remain constant during a recognition cycle.
- RuntimeStatistics shall be updated atomically.

Implementations shall prevent race conditions between the Audio Engine, DSP Engine, and Recognition Engine.

---

# 10.11 Serialization

Only selected Runtime Models may be persisted.

Persistable models include:

- RuntimeConfiguration
- User preferences

Non-persistent models include:

- EngineStatus
- RuntimeContext
- RuntimeStatistics

Runtime operational state shall not survive application termination.

---

# 10.12 Relationship to Other Models

Runtime Models coordinate all major subsystems.

```
RuntimeConfiguration

↓

RuntimeContext

↓

Recognition Engine

↓

RecognitionResult

↓

Diagnostics
```

Unlike Recognition Models, Runtime Models describe the environment in which recognition occurs rather than individual recognition events.

---

# 10.13 Design Constraints

Runtime Models shall remain independent of:

- DSP implementation
- Statistical computation
- Feature extraction
- Command execution
- User interface rendering

Their responsibility is limited to representing the operational state and configuration of the Recognition Engine.

---

# 10.14 Summary

Runtime Models provide the operational framework that governs execution of the Tapper Recognition Engine.

By separating configuration, engine health, runtime context, and operational statistics into dedicated immutable models, the system maintains deterministic behavior, simplifies subsystem coordination, and supports reliable real-time recognition.

The following section defines the Diagnostics Models, which capture runtime logs, performance metrics, and debugging information without affecting recognition behavior.
# 11. Diagnostics Models

## 11.1 Overview

Diagnostics Models represent the operational information generated by the Tapper Recognition System during execution.

Unlike Recognition Models, which represent the outcome of runtime processing, Diagnostics Models exist solely to support monitoring, debugging, validation, benchmarking, and system analysis.

Diagnostics shall never influence recognition decisions.

The Recognition Engine shall remain completely deterministic regardless of whether diagnostics are enabled or disabled.

---

## 11.2 Design Objectives

Diagnostics Models have been designed to satisfy the following objectives:

- Support runtime debugging
- Record performance metrics
- Assist calibration validation
- Facilitate regression testing
- Provide user-visible diagnostics
- Support engineering analysis
- Maintain negligible runtime overhead

Diagnostics are observational only.

They shall never alter runtime behavior.

---

# 11.3 DiagnosticsRecord

## Purpose

DiagnosticsRecord represents a single diagnostic event generated during execution.

Each record captures information describing a significant event occurring within the recognition pipeline.

---

### Canonical Structure

```swift
struct DiagnosticsRecord {

    let id: UUID

    let timestamp: Date

    let level: LogLevel

    let category: DiagnosticsCategory

    let message: String

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| id | UUID | Record identifier |
| timestamp | Date | Event timestamp |
| level | LogLevel | Severity level |
| category | DiagnosticsCategory | Diagnostic subsystem |
| message | String | Human-readable description |

---

### Responsibilities

DiagnosticsRecord shall:

- represent one diagnostic event
- remain immutable
- support structured logging
- provide chronological traceability

---

# 11.4 DiagnosticsCategory

DiagnosticsCategory identifies the subsystem responsible for a diagnostic event.

```swift
enum DiagnosticsCategory {

    case audio

    case dsp

    case calibration

    case classification

    case recognition

    case runtime

    case storage

    case command

}
```

Every DiagnosticsRecord shall belong to exactly one category.

---

# 11.5 PerformanceMetrics

## Purpose

PerformanceMetrics represents quantitative measurements describing runtime performance.

These measurements support optimization and regression testing.

---

### Canonical Structure

```swift
struct PerformanceMetrics {

    let processingLatency: TimeInterval

    let dspLatency: TimeInterval

    let classificationLatency: TimeInterval

    let cpuUsage: Double

    let memoryUsage: Double

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| processingLatency | TimeInterval | Total recognition latency |
| dspLatency | TimeInterval | DSP execution time |
| classificationLatency | TimeInterval | Classification execution time |
| cpuUsage | Double | CPU utilization (%) |
| memoryUsage | Double | Memory consumption (MB) |

---

### Responsibilities

PerformanceMetrics shall:

- measure runtime performance
- support benchmarking
- identify bottlenecks
- remain independent of recognition logic

---

# 11.6 RecognitionLog

## Purpose

RecognitionLog stores a chronological history of RecognitionResults generated during runtime.

Unlike RecognitionSession, which represents a single execution context, RecognitionLog may span multiple sessions for diagnostic purposes.

---

### Canonical Structure

```swift
struct RecognitionLog {

    let entries: [RecognitionResult]

}
```

---

### Responsibilities

RecognitionLog shall:

- preserve recognition history
- support debugging
- enable regression analysis
- facilitate performance evaluation

RecognitionLog shall never contain raw audio data.

---

# 11.7 CalibrationReport

## Purpose

CalibrationReport summarizes the outcome of a completed calibration process.

It provides users and developers with information regarding calibration quality and statistical validity.

---

### Canonical Structure

```swift
struct CalibrationReport {

    let completed: Bool

    let averageQuality: Double

    let samplesCollected: Int

    let generatedAt: Date

}
```

---

### Responsibilities

CalibrationReport shall:

- summarize calibration quality
- support user feedback
- assist troubleshooting
- remain independent of recognition

---

# 11.8 DiagnosticsSnapshot

## Purpose

DiagnosticsSnapshot captures the overall state of the Recognition Engine at a specific point in time.

It aggregates multiple diagnostic models into a single object suitable for inspection or export.

---

### Canonical Structure

```swift
struct DiagnosticsSnapshot {

    let engineStatus: EngineStatus

    let performance: PerformanceMetrics

    let statistics: RuntimeStatistics

}
```

---

### Responsibilities

DiagnosticsSnapshot shall:

- aggregate runtime diagnostics
- support bug reporting
- simplify debugging
- remain immutable

---

# 11.9 Ownership

| Model | Owner |
|--------|-------|
| DiagnosticsRecord | Diagnostics Engine |
| PerformanceMetrics | Runtime Engine |
| RecognitionLog | Diagnostics Engine |
| CalibrationReport | Calibration Engine |
| DiagnosticsSnapshot | Diagnostics Engine |

Ownership shall remain within the diagnostics subsystem.

Recognition components shall not directly modify diagnostic models.

---

# 11.10 Validation Rules

Diagnostics models shall satisfy the following requirements.

### DiagnosticsRecord

- valid timestamp
- valid log level
- valid category
- non-empty message

### PerformanceMetrics

- latency ≥ 0
- CPU usage within valid range
- memory usage ≥ 0

### RecognitionLog

- chronological ordering preserved
- valid RecognitionResults only

Invalid diagnostic data shall be discarded rather than propagated.

---

# 11.11 Thread Safety

Diagnostics Models may be generated concurrently by multiple subsystems.

Accordingly:

- Diagnostic records shall be immutable.
- Log insertion shall be synchronized.
- Snapshot generation shall produce a consistent view.
- Performance metrics shall be updated atomically.

Diagnostic collection shall never block the real-time recognition pipeline.

---

# 11.12 Serialization

Diagnostics Models may be serialized for:

- debugging
- support requests
- regression testing
- performance benchmarking

Serialized diagnostics shall exclude:

- raw microphone recordings
- personally identifiable information
- sensitive user data

Exported diagnostic information shall remain human-readable where practical.

---

# 11.13 Relationship to Other Models

Diagnostics Models observe the entire recognition system.

```
Recognition Engine

↓

RecognitionResult

↓

DiagnosticsRecord

↓

RecognitionLog

↓

DiagnosticsSnapshot
```

Diagnostics consume runtime information but never influence runtime behavior.

---

# 11.14 Design Constraints

Diagnostics Models shall remain independent of:

- statistical classification
- feature extraction
- calibration algorithms
- command execution
- user interface implementation

Their sole responsibility is to observe, record, and report system behavior.

---

# 11.15 Summary

Diagnostics Models provide comprehensive visibility into the operation of the Tapper Recognition System without affecting deterministic recognition.

By separating logging, performance monitoring, calibration reporting, and runtime snapshots into dedicated immutable models, the system supports debugging, validation, benchmarking, and long-term maintenance while preserving the integrity and performance of the recognition pipeline.

The following section defines the Command Models, which represent the executable actions associated with recognized interaction zones.

# 12. Command Models

## 12.1 Overview

Command Models represent the executable actions associated with successful tap recognition.

They form the boundary between the Recognition Engine and the external operating system, applications, and automation frameworks.

Unlike Recognition Models, which determine *what* interaction occurred, Command Models define *what action should be performed* as a consequence of that interaction.

The Recognition Engine shall never execute operating system actions directly. Instead, it shall produce a Command Model that is consumed by a dedicated Command Execution subsystem.

---

## 12.2 Design Objectives

Command Models have been designed to satisfy the following objectives:

- Decouple recognition from execution
- Support multiple command types
- Enable deterministic execution
- Provide platform abstraction
- Facilitate future extensibility
- Support validation before execution
- Preserve execution history

Command Models shall represent executable intent rather than implementation details.

---

# 12.3 Command

## Purpose

Command represents a single executable action generated by the Recognition Engine.

Every successful RecognitionResult maps to exactly one Command.

---

### Canonical Structure

```swift
struct Command {

    let id: UUID

    let type: CommandType

    let target: String

    let parameters: [String: String]

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| id | UUID | Command identifier |
| type | CommandType | Type of executable action |
| target | String | Execution target |
| parameters | Dictionary<String, String> | Optional execution parameters |

---

### Responsibilities

Command shall:

- represent exactly one executable action
- remain immutable
- support serialization
- be independent of recognition logic

---

# 12.4 CommandBinding

## Purpose

CommandBinding associates an InteractionZone with a Command.

It defines the behavior expected when a particular interaction zone is successfully recognized.

---

### Canonical Structure

```swift
struct CommandBinding {

    let zone: InteractionZone

    let command: Command

}
```

---

### Responsibilities

CommandBinding shall:

- map one interaction zone to one command
- remain immutable
- support persistence
- simplify runtime lookup

Every calibrated interaction zone may have at most one active CommandBinding.

---

# 12.5 CommandQueue

## Purpose

CommandQueue represents the collection of Commands awaiting execution.

It isolates recognition from command execution and supports asynchronous processing.

---

### Canonical Structure

```swift
struct CommandQueue {

    let pendingCommands: [Command]

}
```

---

### Responsibilities

CommandQueue shall:

- preserve execution order
- support asynchronous execution
- prevent duplicate execution
- maintain deterministic sequencing

Commands shall be dequeued in first-in, first-out (FIFO) order.

---

# 12.6 CommandResult

## Purpose

CommandResult represents the outcome of an attempted command execution.

Unlike RecognitionResult, which reflects recognition success, CommandResult reflects execution success.

---

### Canonical Structure

```swift
struct CommandResult {

    let commandID: UUID

    let succeeded: Bool

    let completedAt: Date

    let errorMessage: String?

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| commandID | UUID | Executed command identifier |
| succeeded | Bool | Execution status |
| completedAt | Date | Completion timestamp |
| errorMessage | String? | Optional execution error |

---

### Responsibilities

CommandResult shall:

- record execution outcome
- support diagnostics
- remain immutable
- remain independent of recognition

Recognition shall not be repeated if command execution fails.

---

# 12.7 CommandHistory

## Purpose

CommandHistory maintains a chronological record of executed commands.

It supports diagnostics, auditing, and user-visible execution history.

---

### Canonical Structure

```swift
struct CommandHistory {

    let entries: [CommandResult]

}
```

---

### Responsibilities

CommandHistory shall:

- preserve execution history
- support diagnostics
- facilitate auditing
- remain append-only

Historical records shall never modify previously stored CommandResults.

---

# 12.8 Execution Pipeline

The lifecycle of a command is illustrated below.

```
RecognitionResult

↓

CommandBinding

↓

Command

↓

CommandQueue

↓

Command Executor

↓

CommandResult

↓

CommandHistory
```

Recognition and execution remain completely decoupled.

---

# 12.9 Ownership

| Model | Owner |
|--------|-------|
| Command | Recognition Engine |
| CommandBinding | Configuration System |
| CommandQueue | Command Executor |
| CommandResult | Command Executor |
| CommandHistory | Diagnostics System |

Ownership transfers from the Recognition Engine to the Command Execution subsystem after successful recognition.

---

# 12.10 Validation Rules

A valid Command shall satisfy:

- valid UUID
- supported CommandType
- non-empty target
- valid parameter keys and values

A valid CommandBinding shall satisfy:

- valid InteractionZone
- valid Command

A valid CommandResult shall satisfy:

- valid command identifier
- completion timestamp present
- error message provided only when execution fails

Invalid commands shall not enter the execution queue.

---

# 12.11 Thread Safety

Command Models support concurrent recognition and asynchronous execution.

Accordingly:

- Command objects shall be immutable.
- CommandQueue operations shall be synchronized.
- CommandHistory updates shall be atomic.
- CommandResults shall never be modified after creation.

Execution shall not block the Recognition Engine.

---

# 12.12 Serialization

The following models shall support serialization:

- CommandBinding
- CommandHistory
- CommandResult

CommandQueue shall remain transient and shall not be persisted across application restarts.

Serialization shall preserve execution order and command identifiers.

---

# 12.13 Relationship to Other Models

Command Models connect the Recognition Engine to external system behavior.

```
RecognitionResult

↓

CommandBinding

↓

Command

↓

CommandQueue

↓

Command Executor

↓

Operating System
```

They represent executable intent without exposing operating system implementation details to the recognition subsystem.

---

# 12.14 Design Constraints

Command Models shall remain independent of:

- audio acquisition
- digital signal processing
- statistical classification
- calibration procedures
- runtime diagnostics

Their sole responsibility is to represent executable actions generated by successful recognition events.

---

# 12.15 Summary

Command Models define the abstraction layer between acoustic recognition and system interaction.

By representing executable actions, their bindings, execution outcomes, and historical records as immutable, strongly typed models, the Tapper Recognition System achieves a clean separation between recognition and execution. This architecture improves maintainability, supports asynchronous processing, enables future platform portability, and ensures that command execution failures never compromise the deterministic behavior of the recognition engine.

The following section defines the Persistence Models, which govern the storage, retrieval, versioning, and lifecycle management of the system's long-lived data, including calibration profiles, command bindings, and user configuration.

# 13. Persistence Models

## 13.1 Overview

Persistence Models define the long-lived data structures used to store, retrieve, validate, migrate, and manage application data across launches of the Tapper Recognition System.

Unlike Runtime Models, which exist only while the application is executing, Persistence Models survive application termination and represent the canonical stored state of the system.

Persistent data includes calibration profiles, command bindings, application preferences, and metadata required to restore the recognition environment.

Persistence Models shall remain independent of runtime processing and shall never contain transient recognition state.

---

## 13.2 Design Objectives

Persistence Models have been designed to satisfy the following objectives:

- Preserve application state
- Support deterministic loading
- Enable version compatibility
- Maintain data integrity
- Facilitate migration
- Support backup and recovery
- Ensure future extensibility

Persistent storage shall always represent a validated and internally consistent system state.

---

# 13.3 PersistentObject

## Purpose

PersistentObject serves as the common base representation for every persistable entity within the system.

It provides metadata required for identification, versioning, and lifecycle management.

---

### Canonical Structure

```swift
struct PersistentObject {

    let id: UUID

    let version: String

    let createdAt: Date

    let updatedAt: Date

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| id | UUID | Unique object identifier |
| version | String | Schema version |
| createdAt | Date | Creation timestamp |
| updatedAt | Date | Last modification timestamp |

---

### Responsibilities

PersistentObject shall:

- uniquely identify stored entities
- support schema evolution
- enable migration
- remain immutable after loading

---

# 13.4 PersistedCalibrationProfile

## Purpose

PersistedCalibrationProfile represents the serialized form of the active CalibrationProfile.

It enables restoration of the recognition engine without repeating calibration.

---

### Canonical Structure

```swift
struct PersistedCalibrationProfile {

    let profile: CalibrationProfile

    let checksum: String

}
```

---

### Responsibilities

PersistedCalibrationProfile shall:

- preserve statistical calibration
- verify file integrity
- support version validation
- support backup and restoration

Recognition shall not begin until the stored profile has been successfully validated.

---

# 13.5 PersistedCommandBindings

## Purpose

PersistedCommandBindings stores the mapping between interaction zones and executable commands.

---

### Canonical Structure

```swift
struct PersistedCommandBindings {

    let bindings: [CommandBinding]

}
```

---

### Responsibilities

PersistedCommandBindings shall:

- preserve user-defined command mappings
- support editing
- restore bindings during startup
- remain independent of runtime execution

---

# 13.6 UserPreferences

## Purpose

UserPreferences stores configurable application settings selected by the user.

Unlike RuntimeConfiguration, these settings persist across application launches.

---

### Canonical Structure

```swift
struct UserPreferences {

    let diagnosticsEnabled: Bool

    let loggingLevel: LogLevel

    let launchAtLogin: Bool

    let automaticUpdates: Bool

}
```

---

### Responsibilities

UserPreferences shall:

- preserve application preferences
- initialize RuntimeConfiguration
- remain platform-independent
- support future configuration options

Preference changes shall not invalidate calibration profiles.

---

# 13.7 PersistenceManifest

## Purpose

PersistenceManifest represents the complete set of persistent resources managed by the application.

It serves as the root object for loading and saving the application's persistent state.

---

### Canonical Structure

```swift
struct PersistenceManifest {

    let calibrationProfile: PersistedCalibrationProfile

    let commandBindings: PersistedCommandBindings

    let userPreferences: UserPreferences

}
```

---

### Responsibilities

PersistenceManifest shall:

- aggregate all persistent objects
- simplify loading
- simplify backup
- ensure consistent application state

Only one active PersistenceManifest shall exist for a given application instance.

---

# 13.8 Storage Lifecycle

Persistent data follows the lifecycle below.

```
Object Created

↓

Validated

↓

Serialized

↓

Written to Storage

↓

Loaded

↓

Validated

↓

Deserialized

↓

Runtime Object
```

Validation shall occur both before writing and immediately after loading.

---

# 13.9 Ownership

| Model | Owner |
|--------|-------|
| PersistentObject | Persistence Layer |
| PersistedCalibrationProfile | Persistence Layer |
| PersistedCommandBindings | Persistence Layer |
| UserPreferences | Configuration System |
| PersistenceManifest | Persistence Layer |

The Persistence Layer owns all serialized representations.

Runtime subsystems shall consume immutable loaded objects.

---

# 13.10 Validation Rules

Persistent objects shall satisfy the following requirements.

### General

- valid UUID
- supported schema version
- internally consistent timestamps
- checksum validation where applicable

### Calibration

- valid CalibrationProfile
- matching algorithm version
- valid statistical models

### Command Bindings

- unique interaction zones
- valid commands
- supported command types

### User Preferences

- valid Boolean values
- supported logging level

Objects failing validation shall not be loaded.

---

# 13.11 Thread Safety

Persistence Models are immutable after loading.

Accordingly:

- concurrent reads are safe
- writes shall occur through transactional operations
- partially written objects shall never become visible
- loading shall produce fully validated immutable objects

Persistence operations shall not interrupt active recognition.

---

# 13.12 Serialization and Storage

Persistence Models shall support deterministic serialization.

Version 1 shall serialize using:

- JSON for structured data
- UTF-8 encoding
- Double precision for floating-point values
- ISO 8601 timestamps

Implementations shall preserve:

- object ordering
- numerical precision
- schema version
- identifier consistency

---

# 13.13 Versioning and Migration

Every persistent object shall include a schema version.

Migration shall occur only when:

- object schema changes
- algorithm version changes
- feature ordering changes
- statistical representation changes

If migration cannot be completed safely, the object shall be rejected and the user prompted to regenerate the affected data.

---

# 13.14 Relationship to Other Models

Persistence Models provide the bridge between long-lived storage and runtime objects.

```
PersistenceManifest

↓

PersistedCalibrationProfile

↓

CalibrationProfile

↓

RuntimeContext

↓

Recognition Engine
```

The Persistence Layer shall remain transparent to the Recognition Engine after successful loading.

---

# 13.15 Design Constraints

Persistence Models shall remain independent of:

- audio acquisition
- DSP processing
- runtime recognition
- diagnostics collection
- command execution

Their sole responsibility is to provide a reliable, versioned, and deterministic representation of the application's long-lived state.

---

# 13.16 Summary

Persistence Models establish the durable storage architecture of the Tapper Recognition System.

By defining immutable representations for calibration profiles, command bindings, user preferences, and the overall persistence manifest, they ensure that application state can be reliably saved, restored, validated, and migrated across software updates while maintaining strict separation from runtime processing and recognition logic.

The following section defines the **Serialization and Validation Rules**, specifying the canonical encoding, decoding, integrity verification, and compatibility requirements for all persisted models.

# 14. Serialization and Validation Rules

## 14.1 Overview

Serialization and Validation Rules define the canonical procedures for converting Tapper data models into persistent representations and reconstructing them during application startup.

These rules ensure that all persisted objects remain deterministic, portable, version-compatible, and internally consistent throughout their lifecycle.

Serialization shall preserve the complete semantic meaning of every persisted object without introducing ambiguity or loss of precision.

Validation shall guarantee that only structurally correct and logically consistent objects are accepted into the runtime environment.

---

## 14.2 Design Objectives

The serialization and validation framework has been designed to achieve the following objectives:

- Deterministic serialization
- Lossless reconstruction
- Schema validation
- Version compatibility
- Data integrity verification
- Forward extensibility
- Robust error detection

Every persisted object shall successfully complete validation before becoming available to runtime components.

---

# 14.3 Serialization Principles

All persistent models shall follow these fundamental principles.

### Canonical Representation

Every object shall have exactly one canonical serialized representation.

Equivalent objects shall always produce identical serialized output.

---

### Deterministic Ordering

Serialized collections shall preserve deterministic ordering.

Examples include:

- Feature vectors
- Zone profiles
- Command bindings
- Matrix values

Ordering shall never depend upon implementation-specific behavior.

---

### Strong Typing

Every serialized field shall preserve its original data type.

Examples include:

- UUID
- Boolean
- Double
- Integer
- Date
- Enumeration

No implicit type conversion shall occur during serialization.

---

### Numerical Precision

Floating-point values shall be serialized using IEEE-754 Double precision.

Serialization shall not truncate:

- feature values
- covariance matrices
- statistical thresholds
- confidence values

Lossy numerical serialization is prohibited.

---

# 14.4 Serialization Format

Version 1 uses the following canonical encoding.

| Property | Value |
|----------|-------|
| Encoding | UTF-8 |
| Format | JSON |
| Floating Point | Double Precision |
| Dates | ISO 8601 |
| UUID | RFC 4122 String |
| Enumerations | String Representation |

Alternative serialization formats may be introduced in future algorithm versions.

---

# 14.5 Validation Pipeline

Every persisted object shall pass through the following validation pipeline.

```
Read

↓

Decode

↓

Schema Validation

↓

Type Validation

↓

Version Validation

↓

Relationship Validation

↓

Integrity Verification

↓

Runtime Object
```

Failure at any stage shall terminate the loading process.

---

# 14.6 Schema Validation

Schema validation verifies structural correctness.

Validation shall confirm:

- required fields exist
- field types are correct
- mandatory collections are present
- unsupported fields are ignored according to version policy

Malformed objects shall be rejected immediately.

---

# 14.7 Type Validation

Each serialized field shall match its declared type.

Examples include:

| Field | Expected Type |
|--------|---------------|
| UUID | UUID String |
| Date | ISO 8601 |
| Threshold | Double |
| FFT Size | Integer |
| Diagnostics Enabled | Boolean |

Type coercion shall not be performed automatically.

---

# 14.8 Relationship Validation

Relationship validation verifies consistency between interconnected models.

Examples include:

- CommandBinding references valid InteractionZone
- CalibrationProfile contains all required zones
- StatisticalProfile dimensions match FeatureVector dimensions
- RuntimeConfiguration references supported options

Broken relationships invalidate the containing object.

---

# 14.9 Version Validation

Every persisted object shall include a schema version.

Validation shall verify:

- supported schema version
- supported algorithm version
- compatible feature ordering
- compatible statistical representation

Objects originating from unsupported versions shall not be loaded.

---

# 14.10 Integrity Verification

Integrity verification confirms that serialized data has not been corrupted.

Verification mechanisms may include:

- checksum validation
- cryptographic hash verification
- object count verification
- matrix dimension verification

Integrity verification shall occur before deserialization completes.

---

# 14.11 Error Model

Validation failures shall be classified using the following categories.

```swift
enum ValidationError {

    case invalidSchema

    case unsupportedVersion

    case missingField

    case invalidType

    case invalidRelationship

    case integrityFailure

    case deserializationFailure

}
```

Each validation error shall terminate processing of the affected object while allowing unrelated valid objects to continue loading where appropriate.

---

# 14.12 Serialization Lifecycle

Serialization follows the lifecycle below.

```
Runtime Object

↓

Validation

↓

Serialization

↓

Persistent Storage

↓

Deserialization

↓

Validation

↓

Runtime Object
```

Validation occurs both before serialization and after deserialization.

---

# 14.13 Thread Safety

Serialization operations shall satisfy the following requirements.

- Immutable objects may be serialized concurrently.
- Shared storage resources shall be synchronized.
- Validation routines shall be stateless.
- Partial writes shall never become externally visible.

Serialization shall not interfere with active recognition.

---

# 14.14 Performance Considerations

The serialization subsystem shall:

- minimize memory allocations
- avoid duplicate object creation
- support incremental loading where appropriate
- preserve deterministic execution

Validation overhead shall remain negligible relative to application startup time.

---

# 14.15 Relationship to Other Models

Serialization provides the interface between Persistence Models and Runtime Models.

```
Persistent Object

↓

Serializer

↓

Storage

↓

Deserializer

↓

Validator

↓

Runtime Object
```

No subsystem other than the serialization layer shall perform object encoding or decoding.

---

# 14.16 Design Constraints

Serialization and Validation Rules shall remain independent of:

- audio processing
- feature extraction
- statistical classification
- command execution
- user interface

Their sole responsibility is to guarantee accurate, deterministic, and reliable transformation between runtime objects and persistent representations.

---

# 14.17 Summary

Serialization and Validation Rules establish the canonical mechanisms for encoding, decoding, verifying, and reconstructing all persistent data within the Tapper Recognition System.

By enforcing deterministic serialization, strict schema validation, comprehensive integrity verification, and version compatibility, these rules ensure that every persisted object enters the runtime environment in a valid, consistent, and reproducible state, thereby preserving the correctness and long-term maintainability of the system.

The following section defines **Version Compatibility, Thread Safety, Memory Layout, and Object Lifecycle**, which specify the cross-cutting architectural requirements governing the behavior of all data models throughout their existence.

# 15. Version Compatibility, Thread Safety, Memory Layout, and Object Lifecycle

## 15.1 Overview

This section defines the cross-cutting architectural requirements that apply uniformly to every data model within the Tapper Recognition System.

Unlike previous sections, which define specific model categories, this section establishes the universal engineering principles governing model compatibility, concurrent access, memory management, and object lifetime.

These requirements ensure that all models remain deterministic, maintainable, and interoperable across software versions and runtime environments.

---

## 15.2 Design Objectives

The architectural requirements defined in this section have the following objectives:

- Preserve backward compatibility where practical
- Prevent undefined runtime behavior
- Enable safe concurrent execution
- Minimize memory overhead
- Simplify object ownership
- Improve maintainability
- Support future system evolution

These principles apply uniformly to every model defined in this specification.

---

# 15.3 Version Compatibility

## Purpose

Version compatibility ensures that persisted data, calibration profiles, and serialized objects remain compatible with the application that consumes them.

Every persistent model shall explicitly declare the schema and algorithm version under which it was generated.

---

### Compatibility Levels

The system recognizes three compatibility states.

| Status | Description |
|---------|-------------|
| Compatible | Object may be loaded without modification |
| Migratable | Object requires schema migration before use |
| Incompatible | Object cannot be safely loaded |

Only compatible or successfully migrated objects shall enter the runtime environment.

---

### Compatibility Rules

A persisted object shall be considered compatible only if:

- schema version is supported
- algorithm version matches the Recognition Engine
- feature ordering is identical
- statistical dimensions are identical
- required fields are present

Violation of any rule shall invalidate the object.

---

### Migration Policy

Migration shall occur only when:

- structural changes are deterministic
- information loss does not occur
- statistical correctness is preserved

Otherwise, the application shall require regeneration of the affected data.

---

# 15.4 Thread Safety

## Purpose

Thread safety ensures that all models may be accessed correctly in a concurrent runtime environment.

The Tapper Recognition System processes audio, DSP operations, recognition, diagnostics, and command execution concurrently.

Data Models shall therefore support safe concurrent access.

---

### Thread Safety Principles

Unless explicitly stated otherwise:

- models shall be immutable
- concurrent reads shall be permitted
- synchronization shall occur only during construction
- mutable shared state shall be avoided

Immutability is the primary concurrency mechanism employed throughout the architecture.

---

### Synchronization Policy

Synchronization shall be limited to:

- configuration updates
- persistent storage writes
- command queue operations
- diagnostics logging

Recognition Models, Feature Models, and Statistical Models shall require no synchronization after creation.

---

### Concurrent Access Rules

The following operations are always safe.

- concurrent reads
- independent object construction
- serialization of immutable models
- statistical comparisons

The following operations require synchronization.

- queue insertion
- queue removal
- configuration modification
- persistence writes

---

# 15.5 Memory Layout

## Purpose

Memory Layout defines the high-level memory organization of runtime data models.

The objective is to minimize allocation overhead while maximizing cache locality and deterministic performance.

---

### Design Principles

Memory layout shall satisfy the following principles.

- contiguous storage where practical
- predictable object size
- immutable value semantics
- minimal heap allocation
- efficient traversal

---

### Preferred Representation

Small numerical models should be represented using value types.

Examples include:

- Feature
- FeatureVector
- MeanVector
- ThresholdModel
- RuntimeConfiguration

Larger collections may internally reference heap-allocated storage when required by the implementation language.

---

### Memory Ownership

Ownership shall follow a strict hierarchy.

```
Runtime Engine

↓

Recognition Engine

↓

Recognition Models

↓

Released
```

Objects shall have exactly one logical owner during construction.

After publication, immutable objects may be safely shared.

---

### Allocation Strategy

Implementations should:

- reuse temporary buffers
- avoid unnecessary object copying
- minimize allocation during recognition
- preallocate frequently used collections where practical

Recognition latency shall not depend on excessive runtime memory allocation.

---

# 15.6 Object Lifecycle

## Purpose

Every model defined in this specification follows a predictable lifecycle.

Understanding object lifetime simplifies ownership, debugging, and memory management.

---

### Lifecycle States

Every model progresses through the following stages.

```
Constructed

↓

Validated

↓

Published

↓

Consumed

↓

Released
```

Objects shall never bypass validation.

---

### Lifecycle Rules

Every object shall:

- be fully initialized before publication
- become immutable after publication
- remain valid throughout its lifetime
- be released only after all consumers complete processing

Partially initialized objects shall never become externally visible.

---

### Publication

Publication marks the transition from construction to shared usage.

After publication:

- mutation is prohibited
- ownership becomes shared
- concurrent reads are permitted

Publication shall occur only after successful validation.

---

### Destruction

Objects shall become eligible for destruction only after:

- recognition completes
- diagnostics complete
- command execution completes
- no remaining references exist

Object destruction shall be managed automatically by the implementation language whenever possible.

---

# 15.7 Cross-Model Consistency

All Data Models shall satisfy the following consistency requirements.

### Structural Consistency

- canonical field ordering
- immutable public interface
- deterministic construction

### Numerical Consistency

- Double precision throughout
- identical feature ordering
- consistent statistical dimensions

### Behavioral Consistency

- identical validation strategy
- deterministic serialization
- consistent ownership semantics

These requirements apply uniformly to every model within the system.

---

# 15.8 Engineering Guidelines

Implementations should adhere to the following guidelines.

- Favor value semantics over reference semantics where practical.
- Prefer immutable collections after initialization.
- Validate all external data before object construction.
- Keep models free of business logic.
- Separate computation from representation.
- Maintain deterministic behavior under all runtime conditions.

These guidelines promote portability, maintainability, and correctness.

---

# 15.9 Relationship to the Overall Architecture

The architectural principles defined in this section apply to every model introduced throughout this specification.

```
All Data Models

↓

Version Compatibility

↓

Thread Safety

↓

Memory Layout

↓

Object Lifecycle

↓

Runtime System
```

These principles provide a consistent engineering foundation across the entire Tapper architecture.

---

# 15.10 Summary

Version Compatibility, Thread Safety, Memory Layout, and Object Lifecycle establish the universal architectural rules governing every data model within the Tapper Recognition System.

By enforcing explicit version management, immutable concurrency semantics, efficient memory organization, and deterministic object lifecycles, the system achieves predictable behavior, high runtime performance, and long-term maintainability while remaining resilient to future architectural evolution.

The following section defines the **Error Models**, which standardize the representation, classification, propagation, and handling of failures across all components of the Tapper Recognition System.

# 16. Error Models

## 16.1 Overview

Error Models define the canonical representation of failures that may occur within the Tapper Recognition System.

Their purpose is to provide a consistent, deterministic, and implementation-independent mechanism for identifying, classifying, propagating, and reporting errors across all subsystems.

Unlike Diagnostics Models, which describe observations about system behavior, Error Models represent conditions that prevent a subsystem from operating as intended.

Errors shall be explicit, strongly typed, and recoverable whenever practical.

---

## 16.2 Design Objectives

Error Models have been designed to satisfy the following objectives:

- Standardize failure representation
- Enable deterministic error handling
- Simplify debugging
- Support graceful recovery
- Preserve subsystem isolation
- Facilitate diagnostics
- Enable future extensibility

Errors shall never be represented using unstructured strings alone.

---

# 16.3 Error Categories

Every error generated by the Tapper Recognition System shall belong to one of the following categories.

```swift
enum ErrorCategory {

    case audio

    case dsp

    case calibration

    case recognition

    case runtime

    case persistence

    case serialization

    case command

    case diagnostics

    case internal

}
```

Each category corresponds to one architectural subsystem.

---

# 16.4 SystemError

## Purpose

SystemError is the canonical representation of every runtime error.

It provides sufficient information for diagnostics, logging, and recovery while remaining independent of implementation details.

---

### Canonical Structure

```swift
struct SystemError {

    let id: UUID

    let category: ErrorCategory

    let code: ErrorCode

    let severity: ErrorSeverity

    let timestamp: Date

    let message: String

}
```

---

### Field Definitions

| Field | Type | Description |
|--------|------|-------------|
| id | UUID | Unique error identifier |
| category | ErrorCategory | Responsible subsystem |
| code | ErrorCode | Specific error type |
| severity | ErrorSeverity | Error severity |
| timestamp | Date | Time of occurrence |
| message | String | Human-readable description |

---

### Responsibilities

SystemError shall:

- represent exactly one failure
- remain immutable
- support diagnostics
- support serialization

---

# 16.5 ErrorCode

ErrorCode uniquely identifies a specific failure.

```swift
enum ErrorCode {

    case microphoneUnavailable

    case invalidAudioFrame

    case fftFailure

    case invalidFeatureVector

    case calibrationFailed

    case profileNotLoaded

    case recognitionRejected

    case serializationFailure

    case persistenceFailure

    case commandExecutionFailed

    case unknown

}
```

Future algorithm versions may extend this enumeration without modifying existing codes.

---

# 16.6 ErrorSeverity

ErrorSeverity indicates the operational impact of an error.

```swift
enum ErrorSeverity {

    case information

    case warning

    case recoverable

    case critical

    case fatal

}
```

Severity shall determine the appropriate recovery strategy but shall not alter the meaning of the error itself.

---

# 16.7 ErrorContext

## Purpose

ErrorContext provides optional supplementary information describing the environment in which an error occurred.

It supports debugging without becoming part of the core error definition.

---

### Canonical Structure

```swift
struct ErrorContext {

    let subsystem: String

    let operation: String

    let additionalInformation: [String: String]

}
```

---

### Responsibilities

ErrorContext shall:

- provide diagnostic metadata
- remain optional
- avoid implementation-specific details where practical
- remain immutable

Errors remain valid even when no ErrorContext is available.

---

# 16.8 ErrorReport

## Purpose

ErrorReport aggregates one or more SystemErrors into a structured report suitable for diagnostics or support.

---

### Canonical Structure

```swift
struct ErrorReport {

    let generatedAt: Date

    let errors: [SystemError]

}
```

---

### Responsibilities

ErrorReport shall:

- aggregate related failures
- support diagnostics
- simplify troubleshooting
- remain immutable

---

# 16.9 Error Propagation

Errors propagate through the architecture according to the following hierarchy.

```
Subsystem

↓

SystemError

↓

Diagnostics Engine

↓

Application

↓

User Notification
```

Subsystems shall report errors rather than attempting to interpret failures originating from unrelated components.

---

# 16.10 Ownership

| Model | Owner |
|--------|-------|
| SystemError | Originating Subsystem |
| ErrorContext | Originating Subsystem |
| ErrorReport | Diagnostics Engine |

Ownership transfers to the Diagnostics subsystem once an error has been reported.

---

# 16.11 Validation Rules

A valid SystemError shall satisfy:

- valid UUID
- valid ErrorCategory
- valid ErrorCode
- valid ErrorSeverity
- timestamp present
- non-empty message

A valid ErrorReport shall satisfy:

- generation timestamp present
- valid SystemErrors only
- chronological ordering preserved

Invalid error objects shall be discarded.

---

# 16.12 Thread Safety

Error Models are immutable.

Consequently:

- concurrent reads are safe
- error creation is independent
- reports may be shared across threads
- synchronization is required only when inserting errors into shared logs

Error handling shall never block the Recognition Engine.

---

# 16.13 Serialization

Error Models shall support serialization for:

- diagnostics
- support requests
- crash reports
- regression testing

Serialized error reports shall preserve:

- chronological ordering
- identifiers
- timestamps
- severity levels

Sensitive information shall be excluded unless explicitly authorized by the application.

---

# 16.14 Recovery Strategy

Errors shall be handled according to their severity.

| Severity | Expected Behavior |
|----------|-------------------|
| Information | Continue execution |
| Warning | Continue with notification |
| Recoverable | Retry or recover safely |
| Critical | Disable affected subsystem |
| Fatal | Terminate recognition engine safely |

Recovery behavior shall be deterministic and shall never leave the system in an inconsistent state.

---

# 16.15 Relationship to Other Models

Error Models interact with all architectural layers while remaining logically independent.

```
All Subsystems

↓

SystemError

↓

Diagnostics Models

↓

Runtime Models

↓

User Interface
```

Errors describe failures occurring within the system but shall never modify Recognition Models, Statistical Models, or Calibration Models.

---

# 16.16 Design Constraints

Error Models shall remain independent of:

- recognition algorithms
- statistical computation
- audio processing
- command execution
- persistence implementation

Their sole responsibility is to represent and communicate failures in a structured and deterministic manner.

---

# 16.17 Summary

Error Models establish a unified framework for representing, propagating, and reporting failures throughout the Tapper Recognition System.

By defining strongly typed error categories, standardized severity levels, immutable error objects, and deterministic recovery strategies, they enable consistent failure handling across all subsystems while maintaining system integrity, simplifying diagnostics, and supporting long-term maintainability.

The following section defines the **Relationships Between Models**, providing a comprehensive view of how every model introduced in this specification interacts within the overall system architecture.

# 17. Relationships Between Models

## 17.1 Overview

The Tapper Recognition System is composed of a collection of specialized data models, each representing a distinct responsibility within the overall architecture.

This section defines the relationships between those models, illustrating how information flows throughout the system while maintaining strict separation of concerns.

The relationships described herein are conceptual and architectural. They do not prescribe implementation-specific ownership mechanisms such as pointers, references, or memory layouts.

---

## 17.2 Design Objectives

The inter-model architecture has been designed to satisfy the following objectives:

- Maintain clear separation of responsibilities
- Minimize coupling between subsystems
- Maximize modularity
- Enable deterministic data flow
- Simplify maintenance
- Support future extensibility
- Preserve architectural consistency

Each model shall communicate only with models immediately adjacent to it within the architectural pipeline unless explicitly specified otherwise.

---

# 17.3 Architectural Layers

The Tapper Recognition System is organized into nine logical layers.

```
Application Layer

↓

Command Models

↓

Recognition Models

↓

Statistical Models

↓

Calibration Models

↓

Feature Models

↓

DSP Models

↓

Audio Models

↓

Hardware
```

Each layer depends only on the layer immediately beneath it.

Higher layers shall never directly manipulate lower-layer implementation details.

---

# 17.4 Primary Data Flow

The complete recognition pipeline is illustrated below.

```
Microphone

↓

AudioBuffer

↓

AudioFrame

↓

Window

↓

FFTResult

↓

Spectrum

↓

FeatureVector

↓

Candidate

↓

ClassificationResult

↓

RecognitionResult

↓

Command

↓

Operating System
```

Each object is produced exactly once during a recognition cycle and consumed by the subsequent stage.

---

# 17.5 Calibration Data Flow

Calibration introduces an additional processing path responsible for generating statistical models.

```
FeatureVector

↓

CalibrationSample

↓

ZoneCalibration

↓

ZoneProfile

↓

CalibrationProfile

↓

Persistence
```

Following successful calibration, runtime recognition consumes the generated CalibrationProfile without modifying it.

---

# 17.6 Statistical Relationships

Statistical Models are derived from Calibration Models.

```
CalibrationSample

↓

MeanVector

+

CovarianceMatrix

↓

InverseCovarianceMatrix

↓

ThresholdModel

↓

StatisticalProfile
```

These statistical objects collectively define the mathematical representation of a calibrated interaction zone.

---

# 17.7 Runtime Relationships

Runtime Models coordinate execution but do not participate directly in recognition decisions.

```
RuntimeConfiguration

↓

RuntimeContext

↓

Recognition Engine

↓

EngineStatus

↓

RuntimeStatistics
```

Runtime Models provide operational context rather than recognition data.

---

# 17.8 Recognition Relationships

Recognition Models describe the lifecycle of an acoustic event.

```
FeatureVector

↓

Candidate

↓

ClassificationResult

↓

RecognitionResult

↓

CommandBinding

↓

Command
```

Recognition Models terminate once command generation is complete.

---

# 17.9 Command Relationships

Command Models provide the interface between recognition and operating system execution.

```
CommandBinding

↓

Command

↓

CommandQueue

↓

CommandResult

↓

CommandHistory
```

Execution outcomes shall never modify RecognitionResults.

---

# 17.10 Persistence Relationships

Persistence Models bridge runtime objects and long-term storage.

```
CalibrationProfile

↓

PersistedCalibrationProfile

↓

PersistenceManifest

↓

Storage

↓

PersistenceManifest

↓

CalibrationProfile
```

Persistence shall preserve the semantic meaning of all stored models.

---

# 17.11 Diagnostics Relationships

Diagnostics Models observe system behavior across all architectural layers.

```
Recognition Engine

↓

DiagnosticsRecord

↓

RecognitionLog

↓

PerformanceMetrics

↓

DiagnosticsSnapshot
```

Diagnostics consume runtime information but shall never influence recognition behavior.

---

# 17.12 Error Relationships

Error Models provide a standardized mechanism for reporting failures.

```
Subsystem

↓

SystemError

↓

ErrorReport

↓

Diagnostics Engine

↓

User Notification
```

Errors remain orthogonal to the primary recognition pipeline.

---

# 17.13 Ownership Relationships

Ownership progresses through predictable architectural stages.

```
Audio Engine

↓

DSP Engine

↓

Feature Extraction

↓

Recognition Engine

↓

Command Executor

↓

Diagnostics

↓

Released
```

Every runtime object shall have a clearly defined logical owner throughout its lifetime.

Ownership shall transfer only through documented subsystem boundaries.

---

# 17.14 Dependency Rules

The following dependency rules shall apply throughout the architecture.

### Allowed Dependencies

- Audio → DSP
- DSP → Feature
- Feature → Calibration
- Feature → Recognition
- Calibration → Statistical
- Statistical → Recognition
- Recognition → Command
- Runtime → All operational subsystems
- Diagnostics → All subsystems (read-only)
- Persistence → Calibration, Command, Configuration

---

### Prohibited Dependencies

The following dependencies are expressly prohibited.

- Audio → Recognition
- Audio → Command
- DSP → Command
- Statistical → Audio
- Command → DSP
- Command → Calibration
- Diagnostics → Recognition (write access)
- User Interface → Internal model mutation

Violation of these dependency rules constitutes an architectural defect.

---

# 17.15 Cross-Model Consistency

All models shall satisfy the following consistency requirements.

### Structural Consistency

- immutable public interface
- deterministic construction
- explicit ownership

### Numerical Consistency

- Double precision
- canonical feature ordering
- identical statistical dimensions

### Behavioral Consistency

- deterministic serialization
- identical validation strategy
- version compatibility
- thread-safe publication

These consistency guarantees apply uniformly throughout the architecture.

---

# 17.16 Architectural Principles

The following principles govern relationships between all models.

- Each model shall have a single, well-defined responsibility.
- Models shall communicate through strongly typed interfaces.
- Business logic shall remain separate from data representation.
- Cyclic dependencies shall not exist.
- Runtime mutation shall be minimized.
- Immutable models shall be preferred wherever practical.
- Every relationship shall be deterministic and reproducible.

These principles collectively ensure that the architecture remains modular, scalable, and maintainable.

---

# 17.17 Summary

The Relationships Between Models define the structural architecture of the Tapper Recognition System by specifying how information moves between the Audio, DSP, Feature, Calibration, Statistical, Recognition, Runtime, Command, Persistence, Diagnostics, and Error subsystems.

Through clearly defined ownership, dependency rules, and deterministic data flow, the architecture achieves strong separation of concerns while preserving modularity, extensibility, and long-term maintainability.

The following section presents the **UML Model Diagram**, providing a visual representation of the relationships and dependencies defined throughout this specification.

# 18. UML Model Diagram

## 18.1 Overview

This section provides a conceptual Unified Modeling Language (UML) representation of the Tapper Recognition System Data Models.

The objective of this diagram is not to describe implementation-specific classes or programming language constructs, but rather to illustrate the logical relationships, dependencies, ownership, and data flow between the major model categories defined throughout this specification.

The diagrams presented herein are normative with respect to architectural relationships but informative with respect to implementation details.

---

## 18.2 Architectural Overview

The Tapper Recognition System consists of eleven primary model groups.

```
                 +----------------------+
                 |     Audio Models     |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 |      DSP Models      |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 |    Feature Models    |
                 +----------+-----------+
                            |
               +------------+------------+
               |                         |
               v                         v
    +--------------------+     +----------------------+
    | Calibration Models |     | Recognition Models   |
    +----------+---------+     +----------+-----------+
               |                          |
               v                          |
    +----------------------+              |
    | Statistical Models   |<-------------+
    +----------+-----------+
               |
               v
    +----------------------+
    |   Runtime Models     |
    +----------+-----------+
               |
               v
    +----------------------+
    |   Command Models     |
    +----------+-----------+
               |
               v
    +----------------------+
    | Operating System/API |
    +----------------------+
```

This layered architecture enforces unidirectional dependencies and prevents cyclic relationships.

---

# 18.3 Core Recognition Pipeline

The principal runtime data flow is illustrated below.

```
AudioBuffer
     |
     v
AudioFrame
     |
     v
Window
     |
     v
FFTResult
     |
     v
Spectrum
     |
     v
FeatureVector
     |
     v
Candidate
     |
     v
ClassificationResult
     |
     v
RecognitionResult
     |
     v
Command
     |
     v
CommandResult
```

Each model represents a discrete transformation stage within the recognition pipeline.

---

# 18.4 Calibration Model Relationships

Calibration Models construct the statistical representation used by runtime recognition.

```
CalibrationSample
        |
        v
ZoneCalibration
        |
        v
ZoneProfile
        |
        v
CalibrationProfile
        |
        v
PersistedCalibrationProfile
```

Calibration data flows strictly in one direction.

Runtime recognition shall never modify these objects.

---

# 18.5 Statistical Model Relationships

Statistical objects are derived from calibration data.

```
FeatureVector

        |

        v

MeanVector

        +

CovarianceMatrix

        |

        v

InverseCovarianceMatrix

        |

        v

ThresholdModel

        |

        v

StatisticalProfile
```

Every StatisticalProfile corresponds to exactly one interaction zone.

---

# 18.6 Recognition Relationships

Recognition Models describe runtime decision making.

```
FeatureVector
      |
      v
Candidate
      |
      v
ClassificationResult
      |
      v
RecognitionResult
      |
      v
CommandBinding
      |
      v
Command
```

Recognition terminates upon successful command generation.

---

# 18.7 Runtime Relationships

Runtime Models coordinate execution.

```
RuntimeConfiguration

          |

          v

RuntimeContext

          |

          v

EngineStatus

          |

          v

RuntimeStatistics
```

Runtime Models provide operational state but do not influence statistical classification.

---

# 18.8 Persistence Relationships

Persistent storage is represented below.

```
PersistenceManifest

        |

        +----------------------------+

        |                            |

        v                            v

PersistedCalibrationProfile   PersistedCommandBindings

        |                            |

        +-------------+--------------+

                      |

                      v

               UserPreferences
```

Persistence objects aggregate all long-lived application state.

---

# 18.9 Diagnostics Relationships

Diagnostics observe the entire runtime system.

```
RecognitionResult

       |

       v

DiagnosticsRecord

       |

       v

RecognitionLog

       |

       v

PerformanceMetrics

       |

       v

DiagnosticsSnapshot
```

Diagnostics remain observational and do not participate in recognition.

---

# 18.10 Error Relationships

Error propagation follows a separate architectural path.

```
Subsystem

    |

    v

SystemError

    |

    v

ErrorContext

    |

    v

ErrorReport

    |

    v

Diagnostics
```

Errors remain independent of application data models.

---

# 18.11 Ownership Diagram

Ownership of runtime objects progresses through subsystem boundaries.

```
Audio Engine

      |

      v

DSP Engine

      |

      v

Feature Extraction

      |

      v

Recognition Engine

      |

      v

Command Executor

      |

      v

Diagnostics

      |

      v

Released
```

Each subsystem owns objects only during its processing stage.

---

# 18.12 Dependency Diagram

The permitted dependency graph is shown below.

```
Audio
   |
   v
DSP
   |
   v
Feature
  / \
 v   v
Calibration   Recognition
      |           ^
      v           |
 Statistical -----+
      |
      v
 Runtime
      |
      v
 Command
```

No reverse dependencies shall exist.

Circular dependencies are prohibited.

---

# 18.13 Class Relationship Summary

The following table summarizes the principal relationships defined throughout this specification.

| Source Model | Relationship | Target Model |
|--------------|--------------|--------------|
| AudioBuffer | produces | AudioFrame |
| AudioFrame | processed into | Window |
| Window | transformed into | FFTResult |
| FFTResult | generates | Spectrum |
| Spectrum | produces | FeatureVector |
| FeatureVector | creates | Candidate |
| Candidate | classified as | ClassificationResult |
| ClassificationResult | becomes | RecognitionResult |
| RecognitionResult | maps to | Command |
| CalibrationSample | belongs to | ZoneCalibration |
| ZoneCalibration | generates | ZoneProfile |
| ZoneProfile | stored in | CalibrationProfile |
| CalibrationProfile | serialized as | PersistedCalibrationProfile |
| MeanVector | belongs to | StatisticalProfile |
| CovarianceMatrix | belongs to | StatisticalProfile |
| RuntimeConfiguration | used by | RuntimeContext |
| RuntimeContext | controls | Recognition Engine |
| Command | executed by | Command Executor |

---

# 18.14 UML Design Principles

The UML architecture adheres to the following principles.

- Every model has a single responsibility.
- Relationships are unidirectional.
- Runtime objects are immutable after publication.
- Persistent objects are versioned.
- Statistical models are derived exclusively from calibration.
- Recognition never modifies calibration.
- Diagnostics observe without influencing execution.
- Error propagation is orthogonal to recognition.

These principles shall remain valid across future versions of the Tapper Recognition System.

---

# 18.15 Summary

The UML Model Diagram provides a high-level architectural representation of the Tapper Recognition System, illustrating the relationships, dependencies, ownership hierarchy, and data flow between all model categories defined in this specification.

By enforcing layered architecture, unidirectional dependencies, and immutable data flow, the UML design reinforces the system's goals of determinism, modularity, maintainability, and scalability while serving as the conceptual blueprint for implementation.

The following and final section defines **Future Extensions**, outlining anticipated areas of architectural growth and the compatibility principles that will guide future revisions of the Tapper Recognition System.

# 19. Future Extensions

## 19.1 Overview

This specification defines the Version 1 data model architecture for the Tapper Recognition System.

The architecture has been intentionally designed to accommodate future capabilities without compromising the determinism, modularity, and maintainability established throughout this document.

Future extensions shall preserve the core architectural principles defined in this specification while enabling new recognition techniques, hardware capabilities, operating system integrations, and application features.

Unless otherwise specified, future enhancements shall remain backward compatible at the architectural level.

---

## 19.2 Design Philosophy

Future development of the Tapper Recognition System shall be guided by the following principles:

- Preserve deterministic behavior
- Maintain strong separation of concerns
- Favor extensibility over specialization
- Avoid unnecessary architectural complexity
- Minimize breaking changes
- Preserve model immutability
- Maintain implementation independence

Every architectural extension shall build upon existing abstractions rather than replacing them.

---

# 19.3 Recognition Enhancements

Future versions may extend the recognition engine through additional algorithms while preserving the existing Feature Model architecture.

Potential enhancements include:

- adaptive statistical thresholds
- probabilistic confidence estimation
- hybrid deterministic and machine learning classifiers
- ensemble recognition algorithms
- dynamic feature weighting
- multi-stage classification
- gesture recognition through tap sequences

These enhancements shall remain compatible with the existing recognition pipeline wherever practical.

---

# 19.4 Feature Model Expansion

Version 1 defines a fixed ten-dimensional Feature Vector.

Future versions may introduce additional acoustic features, including:

- spectral flatness
- spectral entropy
- spectral flux
- harmonicity
- temporal variance
- cepstral coefficients
- energy distribution metrics
- resonance characteristics

Any modification to FeatureVector dimensionality shall require a new algorithm version and regeneration of calibration profiles.

---

# 19.5 Calibration Improvements

Future calibration capabilities may include:

- adaptive recalibration
- incremental profile refinement
- calibration quality prediction
- automatic outlier detection
- multi-user calibration profiles
- calibration profile merging
- profile portability across compatible devices

The statistical integrity of calibration data shall remain the highest priority.

---

# 19.6 Runtime Enhancements

Runtime functionality may be expanded through:

- background recognition optimization
- energy-aware processing
- hardware acceleration
- dynamic performance tuning
- automatic resource management
- configurable recognition profiles

These enhancements shall remain transparent to Recognition Models.

---

# 19.7 Command System Extensions

Future versions may introduce additional command capabilities.

Examples include:

- command sequences
- conditional commands
- delayed execution
- macro support
- workflow automation
- cloud-based actions
- application-specific integrations

The abstraction provided by Command Models shall remain unchanged.

---

# 19.8 Platform Support

The current architecture has been designed to remain portable across operating systems.

Potential future platforms include:

- macOS
- iPadOS
- iOS
- Windows
- Linux

Platform-specific behavior shall be isolated within implementation layers and shall not modify the canonical Data Models.

---

# 19.9 Cloud and Synchronization

Future releases may support optional synchronization features.

Potential capabilities include:

- cloud backup
- profile synchronization
- encrypted profile sharing
- device migration
- cross-device preferences
- collaborative configuration

Cloud services shall remain optional and shall not become dependencies of the recognition engine.

---

# 19.10 Developer Tooling

Future engineering tools may include:

- visual calibration analyzers
- statistical inspection utilities
- feature visualization tools
- recognition replay systems
- performance profilers
- automated validation suites
- architecture conformance checkers

Developer tooling shall operate using the canonical Data Models defined in this specification.

---

# 19.11 API Evolution

Public interfaces may evolve while preserving architectural compatibility.

Future API enhancements may include:

- asynchronous interfaces
- streaming recognition APIs
- plugin architectures
- scripting interfaces
- package modularization
- third-party extension points

Existing serialized data shall remain compatible whenever feasible.

---

# 19.12 Compatibility Principles

Every future architectural revision shall adhere to the following principles.

### Backward Compatibility

Existing persisted objects should remain usable whenever practical.

---

### Forward Compatibility

Unknown fields shall be ignored unless explicitly required for correctness.

---

### Versioned Evolution

Breaking architectural changes shall require:

- new schema version
- new algorithm version
- documented migration strategy

---

### Deterministic Behavior

No future extension shall compromise the deterministic behavior of the Recognition Engine.

---

# 19.13 Architectural Stability

The following architectural principles are considered fundamental and shall remain unchanged across future versions.

- Layered architecture
- Strong typing
- Immutable runtime models
- Canonical feature ordering
- Deterministic recognition
- Explicit ownership
- Separation of computation and representation
- Unidirectional dependencies

These principles constitute the architectural contract of the Tapper Recognition System.

---

# 19.14 Engineering Roadmap

Future architectural work should prioritize the following areas.

| Priority | Area |
|----------|------|
| High | Recognition accuracy improvements |
| High | Calibration robustness |
| High | Runtime performance optimization |
| Medium | Cross-platform support |
| Medium | Advanced command capabilities |
| Medium | Cloud synchronization |
| Low | Machine learning experimentation |
| Low | Third-party plugin ecosystem |

These priorities are informative and may evolve based on implementation experience and user requirements.

---

# 19.15 Conclusion

The Data Model architecture presented in this specification establishes a comprehensive, strongly typed, and deterministic foundation for the Tapper Recognition System.

By separating responsibilities into dedicated model categories—including Audio, DSP, Feature, Calibration, Statistical, Recognition, Runtime, Diagnostics, Command, Persistence, and Error Models—the architecture achieves a high degree of modularity, maintainability, and extensibility while preserving deterministic behavior and implementation independence.

Future enhancements shall extend this architecture through carefully versioned evolution, ensuring compatibility with existing data wherever practical and maintaining the core design principles that underpin the Tapper Recognition System.

---

## Appendix A — Glossary

| Term | Definition |
|------|------------|
| Feature Vector | Fixed-length numerical representation of an acoustic tap |
| Calibration Profile | Persistent statistical representation of calibrated interaction zones |
| Recognition Engine | Subsystem responsible for classifying acoustic events |
| Statistical Profile | Mathematical model used for runtime classification |
| Runtime Context | Collection of runtime configuration and operational state |
| Command Binding | Association between an interaction zone and an executable command |
| Persistence Manifest | Root object containing all persisted application data |
| Deterministic | Producing identical outputs for identical inputs under identical conditions |

---

## Appendix B — References

1. IEEE Standard for Floating-Point Arithmetic (IEEE 754)
2. ISO 8601 — Date and Time Representation
3. RFC 4122 — Universally Unique Identifier (UUID)
4. Apple Swift API Design Guidelines
5. Apple Human Interface Guidelines (macOS)
6. Apple Accelerate Framework Documentation (vDSP and FFT)
7. Apple AVFoundation Documentation
8. Mahalanobis, P. C. (1936). *On the Generalized Distance in Statistics.*
9. Press, W. H., et al. *Numerical Recipes: The Art of Scientific Computing.*

---

## Appendix C — Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | Initial Release | Initial engineering specification for Version 1 of the Tapper Data Model architecture. |

