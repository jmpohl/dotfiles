try
    using OhMyREPL
catch
    @warn "OhMyREPL not installed"
end

ENV["PYTHON"] = "/Users/jpohl/.local/bin/miniconda2/envs/reo_jump/bin/python"
ENV["JUPYTER"] = "/Users/jpohl/.local/bin/miniconda2/envs/reo_jump/bin/jupyter"
