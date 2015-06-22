class Pidder
  attr_reader  :record, :pid_dir

 def initialize( record, pid_dir)
   @record = record
   @pid_dir = pid_dir
 end

  def create_file(pid)
    file = File.open(pid_file, "w")
    file.write(pid)
    file.close
  end

  def check_running
    pid = process_id
    pid ? Process.kill(0, pid.to_i) : false
  rescue Errno::ESRCH
    false
  end

  private
  def process_id
    return false unless pid_file_exists?
    File.open(pid_file, "r") { |f|
      f.read.chomp
    }
  end

  def pid_file_exists?
    File.exist?(pid_file)
  end

  def pid_file
    @pid_file ||= File.join(File.expand_path(pid_dir), "#{record}.pid")
  end
end
