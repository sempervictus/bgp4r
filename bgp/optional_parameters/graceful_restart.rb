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
  class Graceful_restart < BGP::OPT_PARM::Capability
    def initialize(*args)
      if args.size > 1
        @restart_state, @restart_time = args
        @tuples = []
        super(OPT_PARM::CAP_GR)
      else
        parse(*args)
      end
    end

    def add(afi, safi, af_flags = 0)
      @tuples << [_afi(afi), _safi(safi), af_flags]
    end

    def parse(s)
      @tuples = []
      o1, families = super(s).unpack('na*')
      @restart_state = o1 >> 12
      @restart_time = o1 & 0xfff
      @tuples << families.slice!(0, 4).unpack('nCC') while families.size > 0
    end

    def encode
      s = []
      s << [(@restart_state << 12) + @restart_time].pack('n')
      s << @tuples.collect { |af| af.pack('nCC') }
      super s.join
    end

    def to_s
      s = []
      s <<  "\n    Graceful Restart Extension (#{CAP_GR}), length: #{encode.size}"
      s <<  "    Restart Flags: #{restart_flag}, Restart Time #{@restart_time}s"
      s = s.join("\n  ")
      super + (s + ([''] + @tuples.collect { |af| address_family(*af) }).join("\n        "))
    end

    def method_missing(name, *args, &block)
      if name.to_s =~ /^(.+)_forwarding_state_(.+)/
        state = ::Regexp.last_match(2)
        afi_safi = ::Regexp.last_match(1)
        afi, *safi = afi_safi.to_s.split('_')
        _afi  = IANA.afi?(afi.to_sym)
        _safi = IANA.safi?(safi.join('_').to_sym)
        if state == 'preserved'
          _state = 0x80
        elsif state == 'not_preserved'
          _state = 0
        else
          super
        end
        if _afi and _safi
          add _afi, _safi, _state
        else
          super
        end
      else
        super
      end
    end

    private

    def address_family(afi, safi, flags)
      "AFI #{IANA.afi?(afi)} (#{afi}), SAFI #{IANA.safi?(safi)} (#{safi}), #{address_family_flags(flags)}"
    end

    def restart_flag
      if @restart_state == 0
        '[none]'
      else
        "0x#{@restart_state}"
      end
    end

    def address_family_flags(flags)
      if flags & 0x80 == 0
        "Forwarding state not preserved (0x#{flags.to_s(16)})"
      elsif flags & 0x80 == 0x80
        "Forwarding state preserved (0x#{flags.to_s(16)})"
      else
        "Flags (0x#{flags.to_s(16)}"
      end
    end

    def _afi(val)
      IANA.afi(val)
    end

    def _safi(val)
      IANA.safi(val)
    end
  end
end

load "../../test/unit/optional_parameters/#{File.basename($0.gsub(/.rb/, '_test.rb'))}" if __FILE__ == $0
