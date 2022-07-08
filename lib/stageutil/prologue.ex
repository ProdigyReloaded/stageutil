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

defmodule StageUtil.Prologue do
  defstruct [
    :structure_level,
    :class,
    :au_quanta_size,
    :au_start_offset,
    :map_width,
    :max_map_entries,
    :dir_total_byte_size,
    :cur_start_idx,
    :start_ids,
    :prologue_start_id,
    :checks
  ]

  def decode(file, endian) do
    next_short = fn -> :binary.decode_unsigned(IO.binread(file, 2), endian) end

    {:ok,
     %StageUtil.Prologue{
       structure_level: next_short.(),
       class: next_short.(),
       au_quanta_size: next_short.(),
       au_start_offset: next_short.(),
       map_width: next_short.(),
       max_map_entries: next_short.(),
       dir_total_byte_size: next_short.(),
       cur_start_idx: next_short.(),
       start_ids: [
         %{
           map_start_id: next_short.(),
           dir_start_id: next_short.()
         },
         %{
           map_start_id: next_short.(),
           dir_start_id: next_short.()
         }
       ],
       prologue_start_id: next_short.(),
       checks: next_short.()
     }}
  end
end
