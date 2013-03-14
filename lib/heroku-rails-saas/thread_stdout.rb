# Writes to Thread.current[:stdout] instead of STDOUT if the thread local variable :stdout is set.
# See http://www.jprabawa.com/2012/06/ruby-multithreading-using-subprocesses.html
module ThreadSTDOUT
  def self.write(string)
    if Thread.current[:stdout]
      Thread.current[:stdout].write(string) 
    else
      STDOUT.write(string)
    end
  end

  def self.flush
    if Thread.current[:stdout]
      Thread.current[:stdout].flush
    else
      STDOUT.flush
    end
  end
end