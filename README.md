# LibUSB.jl [![Build Status](https://github.com/emmt/LibUSB.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/emmt/LibUSB.jl/actions/workflows/CI.yml?query=branch%3Amain) [![Build Status](https://ci.appveyor.com/api/projects/status/github/emmt/LibUSB.jl?svg=true)](https://ci.appveyor.com/project/emmt/LibUSB-jl) [![Coverage](https://codecov.io/gh/emmt/LibUSB.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/emmt/LibUSB.jl)

`LibUSB.jl` is a thin package built on top of
[`libusb_jll.jl`](https://github.com/JuliaBinaryWrappers/libusb_jll.jl) to
interface the [`libusb`](https://libusb.info/) C library in
[Julia](https://julialang.org/).

For now, `LibUSB.jl` provides:

- A low level interface (in module `LibUSB.Low`) which is automatically built
  by [`Clang.jl`](https://github.com/JuliaInterop/Clang.jl).

- Some functions and types to manage errors and USB devices in a higher level
  interface.  This part should grow as needed by other packages
  (e.g. [ArcusPerformax.jl](https://github.com/emmt/ArcusPerformax.jl)).
  Nothing is exported so everuthing is prefixed by the module name `LibUSB`.


# Installation

Installing and building the package is as simple as typing the following
commands in Julia:

```julia
using Pkg
pkg"add https://github.com/emmt/LibUSB.jl"
```
