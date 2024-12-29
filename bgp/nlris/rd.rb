#--
# Copyright 2008, 2009 Jean-Michel Esnault.
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

require 'bgp/common'
module BGP
  class Rd
    include ToShex
    attr_reader :admin, :assign

    def bit_length
      64
    end

    def initialize(*args)
      if args.size == 1 and args[0].is_a?(String) and args[0].is_packed?
        parse(args[0])
      elsif args[0].is_a?(self.class)
        parse(args[0].encode, *args[1..-1])
      elsif args.empty?
        @enc_type, @admin, @assign = [0] * 3
      elsif args.size == 3
        admin, assign, @enc_type = args
        case @enc_type
        when 0
          @admin = admin
          @assign = assign
          @enc_type = 0
        when 1
          @enc_type = 1
          @admin = BGPAddr.new(admin)
          @assign = assign
        when 2
          @admin = admin
          @assign = assign
          @enc_type = 2
        end
      elsif args.size == 2
        admin, assign = args
        if admin.is_a?(String)
          @admin = BGPAddr.new(admin)
          @assign = assign
          @enc_type = 1
        elsif assign.is_a?(String)
          @admin = admin
          @assign = BGPAddr.new(assign).to_i
          @enc_type = 2
        else
          @admin = admin
          @assign = assign
          @enc_type = 0
        end
      elsif args.size == 1 and args[0].is_a?(Hash)
        # assuming Rd.new :rd=> [100,100]
        parse(Rd.new(*args[0][:rd]).encode)
      end
    end

    def to_hash
      # FIXME
      if @admin.is_a?(BGPAddr)
        { rd: [@admin.to_s, @assign] }
      else
        { rd: [@admin, @assign] }
      end
    end

    def encode
      case @enc_type
      when 0
        [@enc_type, @admin, @assign].pack('nnN')
      when 1
        [@enc_type, @admin.hton, @assign].pack('na*n')
      when 2
        [@enc_type, @admin, @assign].pack('nNn')
      end
    end

    def parse(s)
      case s[0, 2].unpack('n')[0]
      when 0
        @enc_type, @admin, @assign = s.unpack('nnN')
      when 1
        @enc_type, admin, @assign = s.unpack('na4n')
        @admin = BGPAddr.new_ntoh(admin)
      when 2
        @enc_type, @admin, @assign = s.unpack('nNn')
      else
        puts "Bogus rd ? #{s.unpack('H*')}"
      end
    end

    def to_s(verbose = true)
      if verbose
        case @enc_type
        when 0 then format 'RD=%d:%d (0x%02x 0x%04x)', @admin, @assign, @assign, @assign
        when 1 then format 'RD=%s:%d (0x%04x 0x%02x)', @admin, @assign, @admin.to_i, @assign
        when 2 then format 'RD=%d:%d (0x%04x 0x%02x)', @admin, @assign, @admin, @assign
        end
      else
        case @enc_type
        when 0 then format 'RD=%d:%d', @admin, @assign
        when 1 then format 'RD=%s:%d', @admin, @assign
        when 2 then format 'RD=%d:%d', @admin, @assign
        end
      end
    end

    def encoding_type?
      @enc_type
    end
  end
end
load "../../test/unit/nlris/#{File.basename($0.gsub(/.rb/, '_test.rb'))}" if __FILE__ == $0
