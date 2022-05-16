module LibUSB

# Load the low level interface to the USB library.
let file = joinpath(@__DIR__, "..", "deps", "deps.jl")
    if !isfile(file)
        error("File \"$file\" does not exists.  You may may generate it by:\n",
              "    using Pkg\n",
              "    Pkg.build(\"$(@__MODULE__)\")")
    end
    include(file)
end

const DeviceHandlePointer = Ptr{Low.libusb_device_handle}
const DevicePointer       = Ptr{Low.libusb_device}
const DeviceDescriptor    = Low.libusb_device_descriptor

#------------------------------------------------------------------------------
# ERRORS

const ErrorCode = Union{Integer,Low.libusb_error}

struct USBError <: Exception
    func::Symbol
    code::Cint
end

throw_libusb_error(func::Symbol, code::ErrorCode) =
    throw(USBError(func, Cint(code)))
@noinline throw_libusb_error(func::AbstractString, code::Integer) =
    throw_libusb_error(Symbol(func), code)

error_name(err::USBError) = error_name(err.code)
error_name(code::ErrorCode) = unsafe_string(Low.libusb_error_name(code))

error_message(err::USBError) = error_message(err.code)
error_message(code::ErrorCode) = unsafe_string(Low.libusb_strerror(code))

Base.showerror(io::IO, err::USBError) =
    print(io, error_message(err), " in `", err.func,
          "` [", error_name(err), "]")

#------------------------------------------------------------------------------
# DEVICE LISTS

mutable struct DeviceList <: AbstractVector{DevicePointer}
    ptr::Ptr{DevicePointer}
    len::Int
    function DeviceList()
        ref = Ref{Ptr{DevicePointer}}(0)
        len = Low.libusb_get_device_list(get_context(), ref)
        return finalizer(close, new(ref[], len))
    end
end

# Finalize/close list of devices.
function Base.close(list::DeviceList)
    if !is_null(list.ptr)
        Low.libusb_free_device_list(list.ptr, 1)
        list.ptr = null(list.ptr)
        list.len = 0
    end
    return nothing
end

"""
    LibUSB.DeviceList()
    LibUSB.get_device_list()

yield a list of USB devices.  The two are equivalent.

The returned object is an abstract vector of USB device pointers.

The `close` method can be called to release the resources allocated for the
returned object but this is automatically done when the object is garbage
collected.

"""
get_device_list() = DeviceList()

# Implement abstract array API for device lists.
Base.length(list::DeviceList) = list.len
Base.size(list::DeviceList) = (length(list),)
Base.axes(list::DeviceList) = (Base.OneTo(length(list)),)
Base.IndexStyle(::Type{DeviceList}) = IndexLinear()
#Base.eachindex(list::DeviceList) = Base.OneTo(length(list))
function Base.getindex(list::DeviceList, i::Int)
    1 ≤ i ≤ length(list) || throw(BoundsError(list, i))
    return unsafe_load(list.ptr, i)
end
function Base.setindex(list::DeviceList, x, i::Int)
    error("attempt to set entry in read-only device list")
end

"""
    LibUSB.get_device_descriptor(x)

yields the device descriptor for argument `x` which can be an USB device
pointer, an USB device handle, etc.

"""
function get_device_descriptor(ptr::DevicePointer)
    is_null(ptr) && throw_null_pointer()
    desc = Ref{Low.libusb_device_descriptor}()
    code = Low.libusb_get_device_descriptor(ptr, desc)
    code == 0 || throw_libusb_error(:libusb_device_descriptor, code)
    return desc[]
end

function Base.show(io::IO, dev::DevicePointer)
    print(io, "LibUSB.DevicePointer(0x$(string(UInt(dev), base=16, pad=Sys.WORD_SIZE>>2)))")
    if !is_null(dev)
        desc = get_device_descriptor(dev)
        print(io, " ", string(UInt16(desc.idVendor), base=16, pad=4), ":",
              string(UInt16(desc.idProduct), base=16, pad=4),
              " (bus ", Low.libusb_get_bus_number(dev),
              " device ", Low.libusb_get_device_address(dev), ")")
        path = Vector{UInt8}(undef, 8)
        n = Low.libusb_get_port_numbers(dev, path, sizeof(path))
        if n > 0
            print(io, " path: ", Int(path[1]))
            for i in 2:n
                print(io, ".", Int(path[i]))
            end
        end
    end
end

#------------------------------------------------------------------------------
# DEVICE HANDLES

"""
    open(dev)
    LibUSB.DeviceHandle(dev)

open USB device `dev` and returns an object connected to this device.  The two
functions are equivalent.  The connection is automatically closed when the
returned object is garbage collected.  It is thus not needed to call the
`close` method on the object.

"""
mutable struct DeviceHandle
    handle::DeviceHandlePointer
    descriptor::DeviceDescriptor
    function DeviceHandle(device::DevicePointer)
        descriptor = get_device_descriptor(device)
        handle = Ref{DeviceHandlePointer}()
        code = Low.libusb_open(device, handle)
        code == 0 || throw_libusb_error(:libusb_open, code)
        return finalizer(close, new(handle[], descriptor))
    end
end

Base.open(dev::DevicePointer) = DeviceHandle(dev)

function Base.close(obj::DeviceHandle)
    if !is_null(obj.handle)
        Low.libusb_close(obj.handle)
        obj.handle = null(DeviceHandlePointer)
    end
    return nothing
end

get_device_descriptor(obj::DeviceHandle) = obj.descriptor
Base.unsafe_convert(::Type{DeviceHandlePointer}, obj::DeviceHandle) =
    obj.handle

#------------------------------------------------------------------------------
# UTILITIES

# Global constant reference to store the version of the USB library.  Its value
# is set when the package is loaded.
const LIBUSB_VERSION = Ref{VersionNumber}()

"""
    LibUSB.get_version()

yields the version of the USB library.

"""
get_version() = LIBUSB_VERSION[]

"""
    LibUSB.is_null(ptr)

yields whether `ptr` is a null pointer.

"""
is_null(ptr::Ptr) = (ptr === null(ptr))

"""
    LibUSB.null(ptr)

yields a null pointer of same type as `ptr` (if a pointer instance) or of type
`ptr` (if a pointer type).

"""
null(ptr::Ptr) = null(typeof(ptr))
null(T::Type{<:Ptr}) = T(0)

"""
    LibUSB.throw_null_pointer()

throws a null pointer exception.

"""
throw_null_pointer() = throw(ArgumentError("invalid NULL pointer"))

#------------------------------------------------------------------------------
# INITIALIZATION AND GLOBAL CONTEXT

# Context initialized when package is loaded.  FIXME: (1) Make this a mutable
# object to finalize it when Julia exits.  (2) There may be one such instance
# per Julia thread?
const LIBUSB_CONTEXT = Ref{Ptr{Low.libusb_context}}(0)
get_context() = LIBUSB_CONTEXT[]

function __init__()
    # Initialize C library.
    if is_null(LIBUSB_CONTEXT[])
        code = Low.libusb_init(LIBUSB_CONTEXT)
        code == 0 || throw_libusb_error(:libusb_init, code)
    end
    # Retrieve version. NOTE: The `nano` field is not supported by
    # `VersionNumber`.
    v = unsafe_load(Low.libusb_get_version())
    major = Int(v.major)
    minor = Int(v.minor)
    micro = Int(v.micro)
    rc = unsafe_string(v.rc)
    LIBUSB_VERSION[] = VersionNumber("$major.$minor.$micro$rc")
    return nothing
end

end
