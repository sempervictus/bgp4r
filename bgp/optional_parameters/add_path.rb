#--
# Copyright 2010 Jean-Michel Esnault.
# All rights reserved.
# See LICENSE.txt for permissions.
#
#
# This file is part of BGP4R.
#
# BGP4R is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# BGP4R is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with BGP4R.  If not, see <http://www.gnu.org/licenses/>.
#++

require 'bgp/optional_parameters/capability'

module BGP::OPT_PARM::CAP
  class Add_path < BGP::OPT_PARM::Capability
    class << self
      def new_array(arg)
        o = new
        arg.each { |t| o.add(*t) }
        o
      end
    end

    def initialize(*args)
      @af = {}
      if args.size > 1
        super(OPT_PARM::CAP_ADD_PATH)
        add(*args)
      elsif args.size == 1 and args[0].is_a?(String)
        parse(*args)
      elsif args.empty?
        super(OPT_PARM::CAP_ADD_PATH)
      else
        raise
      end
    end

    def add(sr, _afi, _safi)
      @af[[afi(_afi), safi(_safi)]] = _send_recv(sr)
    end

    def parse(s)
      families = super(s)
      while families.size > 0
        afi, safi, sr = families.slice!(0, 4).unpack('nCC')
        @af[[afi, safi]] = sr
      end
    end

    # 0001 01 01
    # 0002 80 02
    # 0002 01 03

    def send?(afi, safi)
      has? :send, afi, safi
    end

    def recv?(afi, safi)
      has? :recv, afi, safi
    end

    def has?(sr, afi, safi)
      case sr
      when :recv
        @af.has_key?([afi, safi]) && (2..3).include?(@af[[afi, safi]])
      when :send
        @af.has_key?([afi, safi]) && (@af[[afi, safi]] == 1 or @af[[afi, safi]] == 3)
      end
    end

    def encode
      s = []
      s << @af.to_a.sort.collect { |e| e.flatten.pack('nCC') }
      super s.join
    end

    def to_s
      s = []
      s << "\n    Add-path Extension (#{CAP_ADD_PATH}), length: #{encode.size}"
      s = s.join("\n  ")
      super + (s + ([''] + @af.to_a.collect { |e| address_family_to_s(*e) }).join("\n        "))
    end

    private

    def address_family_to_s(af, sr)
      afi, safi = af
      "AFI #{IANA.afi?(afi)} (#{afi}), SAFI #{IANA.safi?(safi)} (#{safi}), #{send_recv_to_s(sr)}"
    end

    def _send_recv(val)
      case val
      when :send, 1 then 1
      when :recv, :receive, 2 then 2
      when :send_and_recv, :send_recv, :send_and_receive, 3 then 3
      else
        val
      end
    end

    def send_recv_to_s(val)
      case val
      when 1 then 'SEND (1)'
      when 2 then 'RECV (2)'
      when 3 then 'SEND_AND_RECV (3)'
      else
        'bogus'
      end
    end

    def afi(arg)
      IANA.afi(arg)
    end

    def safi(arg)
      IANA.safi(arg)
    end
  end
end

load "../../test/unit/optional_parameters/#{File.basename($0.gsub(/.rb/, '_test.rb'))}" if __FILE__ == $0
