# stageutil

**A utility for manipulating STAGE.DAT cache files for the Prodigy Reception System**

## Installation

1. Install elixir per https://elixir-lang.org/install.html
2. Get dependencies with `mix deps.get`
3. Build the script with `mix escript.build`
4. Copy the resulting binary (`stageutil`) to the path of your choice, or run `mix escript.install` and add `~/.mix/escripts` to your `PATH`
5. Run `stageutil` without arguments for usage

## Notes

- The program should work with both STAGE.DAT files intended for classic Mac (big endian) and IBM (little endian), though it does this in a simple manner that is not particularly robust.
- Some STAGE.DAT files encountered either contain malformed data, or the understanding of the file and data structures is imperfect.  These ostensibly corrupt objects will be skipped when possible, and a message emitted.
## Example Usages

### Information on a particular STAGE.DAT

```
% stageutil info mac-v1.0-stage.dat
Source: /tmp/mac-v1.0-stage.dat

          Endian: big
 Structure level: 6
     Quanta Size: 128
       Map Width: 11
 Max Map Entries: 1563
Directory length: 7042
```

### List files matching a pattern

```
% stageutil dir dos-v2.1-stage.dat --glob "*.D"  
Source: /tmp/dos-v2.1-stage.dat

Name          Seq Type # in Set Length Version Storage     Version Check
------------  --- ---- -------- ------ ------- ----------- -------------
ITRC0001.D      1    c        1     25    8070 Required    Yes
TQPDKYWD.D      1    c        0    193    7937 Required    No 
XXME0064.D      1    c        0    129    8000 Stage       No 
XXME0067.D      1    c        0    131    8000 Stage       No 
XXMH0011.D      1    c        0    249    8000 Required    No 
XXMH0012.D      1    c        0    283    8000 Required    No 
XXMH0BCD.D      1    c        0    271    7937 Required    No 

```

The column meanings are as follows:
#### Name
The name of the object as encoded in the first 11 bytes.  The "." is not included with the encoded name.

#### Seq
This is the sequence of item within the set of items.  For example, the News Headlines `NH00A000.B` may be a set of
99 items, so this sequence may range from 1 to 99.

#### Type
This is the type of object, in hexadecimal, as shown in the example for `list-object-types` below.

#### # in Set
This is the number of items in the set, as described in Seq above.  Note: The size may be 0, but the sequence 1.

#### Version
This is the numeric version of the object.  The reception system sends this to the server when seeking object updates.

#### Storage
This indicates the eligibility of the Object for storage within, or eviction from the various reception system caches:

* ##### Cache
  * This item is generally eligible to only be stored in the `CACHE.DAT` file, which is overwritten every session.  It can be stored in `STAGE.DAT`, but will be evicted in deference to a newly retrieved file with Stage candidacy.
* ##### None
  * This item is generally only eligible to be memory resident, or embedded within another object that has Stage or Cache candidacy.
* ##### Stage
  * This item is eligible for retention in the `STAGE.DAT` file, which persists across sessions
* ##### Required
  * This item is required at all times, and is never eligible for eviction from `STAGE.DAT`
* ##### Large Stage
  * This item is eligible only for the larger `STAGE.DAT` created by RS 8+

#### Versioning

* ##### Yes
  * The object is always version checked when first accessed during a session.
* ##### No
  * The object is only version checked when the Reception Control Object `ITRC0001.D` version is incremented with respect to the one stored within `STAGE.DAT`





### Recursive export all program files with names matching a particular pattern 

```
% stageutil export dos-v2.1-stage.dat --glob "MS*.PGM" --recurse --dest ./out
% ls out   
MSZB010X.PGM MSZB011X.PGM MSZB012E.PGM MSZB014X.PGM MSZB016X.PGM MSZW010A.PGM
MSZW010H.PGM MSZW010X.PGM MSZW011X.PGM MSZW016X.PGM MSZW020A.PGM MSZX000A.PGM
MSZX010E.PGM MSZX010X.PGM
```

### List Object Types
The object type corresponds to the "type" column in the directory listing.

```
% stageutil list-object-types
Object Types

0x0 - Page Format Object
0x4 - Page Template Object
0x8 - Page Element Object
0xC - Program Object
0xE - Window Object
```

## Credits

This work is a derivative of the [original Python implementation](https://github.com/jim02762/prodigy-classic-tools) by
Jim Carpenter.  Jim did most of the hard work to determine the structure of these files.  stageutil came about mostly
as an exercise to learn more about elixir, and only has  marginal improvements to handle Mac files and odd file names.
Jim's tool has many more features for introspecting the structure of `STAGE.DAT` and is worth a look.