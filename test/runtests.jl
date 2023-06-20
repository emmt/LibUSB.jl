module TestingLibUSB

using LibUSB
using Test

@testset "LibUSB.jl" begin
    @test_throws LibUSB.USBError LibUSB.throw_libusb_error(
        :libusb_get_device_descriptor, LibUSB.Low.LIBUSB_ERROR_NO_DEVICE)
    @test LibUSB.error_name(LibUSB.Low.LIBUSB_ERROR_IO) == "LIBUSB_ERROR_IO"
    @test LibUSB.error_message(LibUSB.Low.LIBUSB_ERROR_ACCESS) isa String
    @test LibUSB.get_version() isa VersionNumber
    list = LibUSB.DeviceList()
    @test list isa AbstractVector
    @test axes(list) == (1:length(list),)
    @test IndexStyle(list) === IndexLinear()
    @test_throws BoundsError list[0]
    @test_throws BoundsError list[length(list)+1]
    if length(list) > 0
        @test list[1] isa eltype(list)
        @test LibUSB.get_device_descriptor(list[1]) isa LibUSB.Low.libusb_device_descriptor
    end
    io = IOBuffer()
    @test last(show(io, list) => true)
    @test_throws Exception list[1] = eltype(list)(0)
    close(list)
    @test length(list) == 0
    @test LibUSB.is_null(list.ptr)
end

end # module
