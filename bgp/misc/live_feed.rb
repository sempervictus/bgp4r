# require 'net/telnet'
require 'bgp4r'

class LiveFeed
  def self.open
    new.open
  end

  def open
    @host = '129.82.138.6'
    @port = '50001'
    @buf = ''
    @queue = Queue.new

    Thread.new do
      @feed = TCPSocket.new @host, @port
      loop do
        @buf += @feed.recv(5000)
      end
    end
    @th = Thread.new do
      loop do
        pos = (@buf =~ %r{<OCTETS length=.*>([^<]*)</OCTETS>})
        next unless pos

        @queue.enq [::Regexp.last_match(1)].pack('H*')
        @buf.slice!(0, pos + 10)
        sleep(0.1)
      end
    end
    self
  end

  def close
    @th.kill
    @feed.close
  end

  def read
    @queue.deq
  end
  alias msg read
  alias readmessage read
end
