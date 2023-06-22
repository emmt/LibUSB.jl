let filename = joinpath(@__DIR__, "reallyruntests.jl")
    @info """
    If package LibUSB has been successfully built, you may test it if you have
    access to USB devices. To really run tests, call:

              include(\"$filename\")

          from Julia or execute:

              julia \"$filename\"

          from the shell.
    """
end
