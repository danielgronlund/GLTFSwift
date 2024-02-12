# GLTFSwift

`GLTFSwift` is a basic Swift library designed to parse GLTF (GL Transmission Format) files and convert them into Metal buffers.

### Features

- **GLTF Parsing**: Load GLTF files to access scenes, nodes, meshes, and skins.
- **Metal Buffer Conversion**: Convert parsed data into Metal buffers for

## Usage

```swift
import GLTFSwift

let scene = try Scene.load(from: "model.gltf", device: yourMetalDevice)
// Use the loaded scene with your Metal setup
```

### Disclaimer

Please note, `GLTFSwift` is in its early stages and covers only the very basics of GLTF file handling and Metal buffer conversion. It is far from a complete solution and is intended for educational or prototyping purposes.
