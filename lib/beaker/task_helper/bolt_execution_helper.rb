require 'beaker'
require 'open3'

module Beaker::TaskHelper::BoltExecutionHelper # rubocop:disable Style/ClassAndModuleChildren

  BOLT_HOST_ERROR = 'host must be "localhost" or an instance of BeakerHost class'
  BOLT_OPTIONS_ERROR = 'bolt_options must be a Hash'

  # a helper designed to help run bolt commands on localhost or a bolt node
  # will run on localhost unless there is a host with the role 'bolt'
  def bolt(command, bolt_options = {}, opts={}, &block)
    host = find_at_most_one('bolt') || :localhost
    bolt_on(host, command, bolt_options, opts, &block)
  end

  # use this method if you need to specify a specific host to run a command on
  def bolt_on(host, command, bolt_options = {}, opts = {}, &block)
    bolt_cmd = generate_bolt_command(command, bolt_options)
    if host.is_a?(Beaker::Host)
      platform = host['platform']
      # I dont think we want to pass any ps args to powershell
      beaker_cmd = (platform =~ /win/i) ? powershell(bolt_cmd) : Beaker::Command.new(bolt_cmd)
      bolt_on_host(host, beaker_cmd, opts, &block)
    elsif host.to_s =~ /localhost/i
      bolt_on_localhost(Beaker::Command.new(bolt_cmd), opts, &block)
    else
      raise(ArgumentError, BOLT_HOST_ERROR)
    end
  end

  def bolt_on_localhost(command, options, &block)

    blocks = {
      combined: [],
      out: [],
      err: []
    }
    exit_code = -1
    Open3.popen3(opts[:environment] || {}, command, opts) do |stdin, stdout, stderr, wait_thr|
      # TODO: pass through $stdin/terminal to subprocess to allow interaction - e.g. pry - the subprocess
      stdin.close_write

      files = [stdout, stderr]

      until files.all?(&:eof)
        ready = IO.select(files)
        next unless ready

        ready[0].each do |f|
          fileno = f.fileno
          begin
            begin
              data = f.read_nonblock(1024)
            rescue IO::WaitReadable, Errno::EINTR
              IO.select([f])
              retry
            end
            until data.empty?
              $stdout.write(data)

              # create a combined block list for better output interleaving
              blocks[:combined] << data

              # store each stream separately for the Beaker::Result API
              if fileno == stdout.fileno
                blocks[:out] << data
              else
                blocks[:err] << data
              end

              # try reading more data
              # when the command writes more than 1k at a time, this is required to drain buffers
              # and avoid stdout/stderr interleaving
              begin
                data = f.read_nonblock(1024)
              rescue IO::EAGAINWaitReadable
                data = ""
              rescue IO::WaitReadable, Errno::EINTR
                IO.select([f])
                retry
              end
            end
          rescue EOFError, Errno::EBADF # rubocop:disable Lint/HandleExceptions: expected exception
            # pass on EOF
            # Also pass on Errno::EBADF (Bad File Descriptor) as it is thrown for Ruby 2.1.9 on Windows
          end
        end
      end

      exit_code = wait_thr.value.exitstatus
    end
    result = Beaker::Result.new(:localhost, command)
    result.stdout = blocks[:out].join
    result.stderr = blocks[:err].join
    result.output = blocks[:combined].join
    result.exit_code = exit_code
    result.finalize!

    # taken from Beaker::Host 'exec'
    if options[:accept_all_exit_codes] && options[:acceptable_exit_codes]
      @logger.warn ":accept_all_exit_codes & :acceptable_exit_codes set. :acceptable_exit_codes overrides, but they shouldn't both be set at once"
      options[:accept_all_exit_codes] = false
    end
    if !options[:accept_all_exit_codes] && !result.exit_code_in?(Array(options[:acceptable_exit_codes] || [0, nil]))
      raise CommandFailure, "Host 'localhost' exited with #{result.exit_code} running:\n #{cmdline}\nLast #{@options[:trace_limit]} lines of output were:\n#{result.formatted_output(@options[:trace_limit])}"
    end

    if block_given?
      case block.arity
        #block with arity of 0, just hand back yourself
        when 0
          yield self
        #block with arity of 1 or greater, hand back the result object
        else
          yield result
      end
    end
    result
  end

  # @private
  def bolt_on_host(host, command_object, opts, &block)
    result = host.exec(command_object, opts)

    if block_given?
      case block.arity
        #block with arity of 0, just hand back yourself
        when 0
          yield self
        #block with arity of 1 or greater, hand back the result object
        else
          yield result
      end
    end
    result
  end

  # @private
  def generate_bolt_command(command, bolt_options)
    raise(ArguementError, BOLT_OPTIONS_ERROR) unless bolt_options.is_a?(Hash)
    cmd = command.dup
    bolt_options.each { |k, v| cmd << " #{k} #{v}" }
    cmd
  end
end
