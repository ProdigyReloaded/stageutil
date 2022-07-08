# Copyright 2022, Phillip Heller
#
# This file is part of StageUtil.
#
# StageUtil is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# StageUtil is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
# the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with StageUtil. If not,
# see <https://www.gnu.org/licenses/>.

defmodule StageUtil.Aum do
  import Bitwise

  defp auid_to_offset(prologue, auid) do
    prologue.au_start_offset + (auid - prologue.prologue_start_id) * prologue.au_quanta_size
  end

  # STAGE.DAT files utilize an Allocation Unit Map with Allocation Units identified by a variable
  # width integer, commonly 11 or 12 bits.  To save space, the integers are sequentially packed and
  # not byte aligned.  As an example, given an 9 bit map, the integers would be comprised of bits
  # numbered 1 to 9 as shown below:
  #
  # 87654321 | 76543219 | 65432198 | 54321987 | ...
  # aaaaaaaa   bbbbbbba   ccccccbb   dddddccc

  # this is the base case, return the entries that have been read
  defp decode(_, 0, _, _, _, _, map) do
    map
  end

  # When there are not enough bytes in the buffer to extract a width-sized integer considering some
  # of the bits in the buffer may belong to a previously extracted integer, read another byte,
  # prepend it to the buffer, and recurse
  defp decode(file, entries_remaining, width, mask, mask_offset, buffer, map)
       when byte_size(buffer) * 8 - mask_offset < width do
    decode(file, entries_remaining, width, mask, mask_offset, IO.binread(file, 1) <> buffer, map)
  end

  # There are now enough bytes to extract a width-sized integer; extract it and shift the
  # mask for the next read, and recurse
  defp decode(file, entries_remaining, width, mask, mask_offset, buffer, map) do
    trim = div(mask_offset, 8)
    new_buffer = binary_part(buffer, 0, byte_size(buffer) - trim)
    new_mask_offset = mask_offset - trim * 8
    new_mask = mask >>> (trim * 8)

    i = :binary.decode_unsigned(new_buffer, :big)
    value = (i &&& new_mask) >>> new_mask_offset

    decode(file, entries_remaining - 1, width, new_mask <<< width, new_mask_offset + width, new_buffer, map ++ [value])
  end

  # this is the entry point for decoding the allocation map
  def decode(file, prologue, auid) do
    offset = auid_to_offset(prologue, auid)
    :file.position(file, offset)

    next_short = fn -> :binary.decode_unsigned(IO.binread(file, 2), :big) end
    _mapcheck = next_short.()
    _dircheck = next_short.()

    {:ok, _pos} = :file.position(file, :cur)

    decode(file, prologue.max_map_entries, prologue.map_width, (1 <<< prologue.map_width) - 1, 0, <<>>, [])
  end

  # each file in an allocation map is comprised of some number of consecutive allocation units called a chain.
  # The beginning of the chain is some known number, and then the number in that entry of the map and every
  # subsequent map entry ...
  def read_chain(file, prologue, aumap, start_id) do
    private_read_chain(file, prologue, [start_id] ++ Enum.slice(aumap, (start_id - 2)..-1), <<>>)
  end

  # ... until the end-of-chain sentinal value of "1" is observed, as here.  When that value is observed, the
  # accumulated allocation units comprise the chain, and the data found within those units concatenated comprises
  # the file.
  def private_read_chain(file, prologue, [auid | rest], buf) do
    case auid do
      1 ->
        # we have now seen the sentinel value, so all of the file in question has been read and is in buf, return it
        buf

      _ ->
        offset = auid_to_offset(prologue, auid)
        :file.position(file, offset)

        data = case IO.binread(file, prologue.au_quanta_size) do
          {:error, _reason} -> raise "truncated"
          {:eof} -> raise "truncated"
          data -> data
        end

        # append the data from this specific allocation unit to the data already read
        private_read_chain(file, prologue, rest, buf <> data)
    end
  end

  def private_read_chain(_file, _prologue, [], _buf) do
    raise "truncated"
  end

  # The directory is simply a file in the allocation map with a known structure.  It's starting allocation id is
  # known from the file prologue.
  def read_directory(endian, file, prologue, aumap, start_id) do
    dir_bytes = read_chain(file, prologue, aumap, start_id)
    parse_directory(endian, file, prologue, aumap, dir_bytes)
  end

  # if little endian, process the integers as such
  def parse_directory(:little = endian, file, prologue, aumap,
        <<map_check::16-little, dir_check::16-little, create_date::32-big, modify_date::32-big,
          novclass::16-little, inuse::16-little, maximum::16-little, usageoff::16-little,
          entryoff::16-little, rest::binary>>
      ) do
    parse_directory(endian, file, prologue, aumap, map_check, dir_check, create_date, modify_date, novclass, inuse,
      maximum, usageoff, entryoff, rest)
  end

  # if big endian, process the integers as such
  def parse_directory( :big = endian, file, prologue, aumap,
        <<map_check::16-big, dir_check::16-big, create_date::32-big, modify_date::32-big,
          novclass::16-big, inuse::16-big, maximum::16-big, usageoff::16-big, entryoff::16-big,
          rest::binary>>
      ) do
    parse_directory(endian, file, prologue, aumap, map_check, dir_check, create_date, modify_date, novclass, inuse,
      maximum, usageoff, entryoff, rest)
  end

  # now parse the directory with integers in host order
  def parse_directory(endian, file, prologue, aumap, map_check, dir_check, create_date, modify_date, novclass, inuse,
        maximum, usageoff, entryoff, rest) do
    _candidacy = (novclass &&& 0xE000) >>> 13
    _version = novclass &&& 0x1FFF

    usagesize = maximum * 2

    entries = case byte_size(rest) >= usagesize do
      true ->
        <<_usage::binary-size(usagesize), entries::binary>> = rest
        parse_directory_entries(endian, file, prologue, aumap, inuse, entries)

      false ->
        []
    end

     %{
       map_check: map_check,
       dir_check: dir_check,
       create_date: create_date,
       modify_date: modify_date,
       novclass: novclass,
       inuse: inuse,
       maximum: maximum,
       usageoff: usageoff,
       entryoff: entryoff,
       entries: entries
     }
  end

  # define a default for "entries" in the subsequent methods
  def parse_directory_entries(endian, file, prologue, aumap, inuse_count, data, entries \\ [])

  # base case, nothing more, return the accumulated entries
  def parse_directory_entries(_endian, _file, _prologue, _aumap, 0, _, entries) do
    entries
  end

  # if big endian, process the integers as such
  def parse_directory_entries(:big = endian, file, prologue, aumap, inuse,
        <<id::binary-size(13), _, status::16-big, length::16-big, startid::16-big,
          novclass::16-big, check::16, rest::binary>>, entries) do
    parse_directory_entries(endian, file, prologue, aumap, inuse, id, status, length, startid, novclass, check,
      rest, entries)
  end

  # if big endian, process the integers as such
  def parse_directory_entries(:little = endian, file, prologue, aumap, inuse,
        <<id::binary-size(13), _, status::16-little, length::16-little, startid::16-little,
          novclass::16-little, check::16, rest::binary>>, entries) do
    parse_directory_entries( endian, file, prologue, aumap, inuse, id, status, length, startid, novclass, check,
      rest, entries)
  end

  # now parse the directory entries with integers in host order
  def parse_directory_entries(endian, file, prologue, aumap, inuse, id, status, length, startid, novclass, check,
        rest, entries) do
    <<name::binary-size(8), ext::binary-size(3), seq, type>> = id

    filename = String.trim("#{name}.#{ext}")

    entry = %{
      filename: filename,
      sequence: seq,
      type: type,
      status: status,
      length: length,
      startid: startid,
      novclass: novclass,
      check: check
    }

    # append this entry to the cumulative list and recurse
    parse_directory_entries(endian, file, prologue, aumap, inuse - 1, rest, entries ++ [entry])
  end
end
