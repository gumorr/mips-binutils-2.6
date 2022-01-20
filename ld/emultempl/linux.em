# This shell script emits a C file. -*- C -*-
# It does some substitutions.
cat >e${EMULATION_NAME}.c <<EOF
/* This file is is generated by a shell script.  DO NOT EDIT! */

/* Linux a.out emulation code for ${EMULATION_NAME}
   Copyright (C) 1991, 1993, 1994 Free Software Foundation, Inc.
   Written by Steve Chamberlain <sac@cygnus.com>
   Linux support by Eric Youngdale <ericy@cais.cais.com>

This file is part of GLD, the Gnu Linker.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */

#define TARGET_IS_${EMULATION_NAME}

#include "bfd.h"
#include "sysdep.h"
#include "bfdlink.h"

#include "ld.h"
#include "ldmain.h"
#include "ldemul.h"
#include "ldfile.h"
#include "ldmisc.h"
#include "ldexp.h"
#include "ldlang.h"

static void gld${EMULATION_NAME}_before_parse PARAMS ((void));
static boolean gld${EMULATION_NAME}_open_dynamic_archive
  PARAMS ((const char *, search_dirs_type *, lang_input_statement_type *));
static void gld${EMULATION_NAME}_find_address_statement
  PARAMS ((lang_statement_union_type *));
static void gld${EMULATION_NAME}_create_output_section_statements
  PARAMS ((void));
static void gld${EMULATION_NAME}_before_allocation PARAMS ((void));
static char *gld${EMULATION_NAME}_get_script PARAMS ((int *isfile));

static void
gld${EMULATION_NAME}_before_parse()
{
  ldfile_output_architecture = bfd_arch_${ARCH};
  config.dynamic_link = true;
}

/* Try to open a dynamic archive.  This is where we know that Linux
   dynamic libraries have an extension of .sa.  */

static boolean
gld${EMULATION_NAME}_open_dynamic_archive (arch, search, entry)
     const char *arch;
     search_dirs_type *search;
     lang_input_statement_type *entry;
{
  char *string;

  if (! entry->is_archive)
    return false;

  string = (char *) xmalloc (strlen (search->name)
			     + strlen (entry->filename)
			     + strlen (arch)
			     + sizeof "/lib.sa");

  sprintf (string, "%s/lib%s%s.sa", search->name, entry->filename, arch);

  if (! ldfile_try_open_bfd (string, entry))
    {
      free (string);
      return false;
    }

  entry->filename = string;

  return true;
}

/* This is called by the create_output_section_statements routine via
   lang_for_each_statement.  It locates any address assignment to
   .text, and modifies it to include the size of the headers.  This
   causes -Ttext to mean the starting address of the header, rather
   than the starting address of .text, which is compatible with other
   Linux tools.  */

static void
gld${EMULATION_NAME}_find_address_statement (s)
     lang_statement_union_type *s;
{
  if (s->header.type == lang_address_statement_enum
      && strcmp (s->address_statement.section_name, ".text") == 0)
    {
      ASSERT (s->address_statement.address->type.node_class == etree_value);
      s->address_statement.address->value.value += 0x20;
    }
}

/* This is called before opening the input BFD's.  */

static void
gld${EMULATION_NAME}_create_output_section_statements ()
{
  lang_for_each_statement (gld${EMULATION_NAME}_find_address_statement);
}

/* This is called after the sections have been attached to output
   sections, but before any sizes or addresses have been set.  */

static void
gld${EMULATION_NAME}_before_allocation ()
{
  if (link_info.relocateable)
    return;

  /* Let the backend work out the sizes of any sections required by
     dynamic linking.  */
  if (! bfd_linux_size_dynamic_sections (output_bfd, &link_info))
    einfo ("%P%F: failed to set dynamic section sizes: %E\n");
}

static char *
gld${EMULATION_NAME}_get_script(isfile)
     int *isfile;
EOF

if test -n "$COMPILE_IN"
then
# Scripts compiled in.

# sed commands to quote an ld script as a C string.
sc='s/["\\]/\\&/g
s/$/\\n\\/
1s/^/"/
$s/$/n"/
'

cat >>e${EMULATION_NAME}.c <<EOF
{			     
  *isfile = 0;

  if (link_info.relocateable == true && config.build_constructors == true)
    return `sed "$sc" ldscripts/${EMULATION_NAME}.xu`;
  else if (link_info.relocateable == true)
    return `sed "$sc" ldscripts/${EMULATION_NAME}.xr`;
  else if (!config.text_read_only)
    return `sed "$sc" ldscripts/${EMULATION_NAME}.xbn`;
  else if (!config.magic_demand_paged)
    return `sed "$sc" ldscripts/${EMULATION_NAME}.xn`;
  else
    return `sed "$sc" ldscripts/${EMULATION_NAME}.x`;
}
EOF

else
# Scripts read from the filesystem.

cat >>e${EMULATION_NAME}.c <<EOF
{			     
  *isfile = 1;

  if (link_info.relocateable == true && config.build_constructors == true)
    return "ldscripts/${EMULATION_NAME}.xu";
  else if (link_info.relocateable == true)
    return "ldscripts/${EMULATION_NAME}.xr";
  else if (!config.text_read_only)
    return "ldscripts/${EMULATION_NAME}.xbn";
  else if (!config.magic_demand_paged)
    return "ldscripts/${EMULATION_NAME}.xn";
  else
    return "ldscripts/${EMULATION_NAME}.x";
}
EOF

fi

cat >>e${EMULATION_NAME}.c <<EOF

struct ld_emulation_xfer_struct ld_${EMULATION_NAME}_emulation = 
{
  gld${EMULATION_NAME}_before_parse,
  syslib_default,
  hll_default,
  after_parse_default,
  after_open_default,
  after_allocation_default,
  set_output_arch_default,
  ldemul_default_target,
  gld${EMULATION_NAME}_before_allocation,
  gld${EMULATION_NAME}_get_script,
  "${EMULATION_NAME}",
  "${OUTPUT_FORMAT}",
  NULL,
  gld${EMULATION_NAME}_create_output_section_statements,
  gld${EMULATION_NAME}_open_dynamic_archive
};
EOF
