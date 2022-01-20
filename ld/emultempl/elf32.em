# This shell script emits a C file. -*- C -*-
# It does some substitutions.
cat >e${EMULATION_NAME}.c <<EOF
/* This file is is generated by a shell script.  DO NOT EDIT! */

/* 32 bit ELF emulation code for ${EMULATION_NAME}
   Copyright (C) 1991, 1993, 1994, 1995 Free Software Foundation, Inc.
   Written by Steve Chamberlain <sac@cygnus.com>
   ELF support by Ian Lance Taylor <ian@cygnus.com>

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

#include <ctype.h>

#include "bfdlink.h"

#include "ld.h"
#include "ldmain.h"
#include "ldemul.h"
#include "ldfile.h"
#include "ldmisc.h"
#include "ldexp.h"
#include "ldlang.h"
#include "ldgram.h"

static void gld${EMULATION_NAME}_before_parse PARAMS ((void));
static boolean gld${EMULATION_NAME}_open_dynamic_archive
  PARAMS ((const char *, search_dirs_type *, lang_input_statement_type *));
static void gld${EMULATION_NAME}_after_open PARAMS ((void));
static void gld${EMULATION_NAME}_check_needed
  PARAMS ((lang_input_statement_type *));
static void gld${EMULATION_NAME}_stat_needed
  PARAMS ((lang_input_statement_type *));
static boolean gld${EMULATION_NAME}_search_needed
  PARAMS ((const char *, const char *));
static boolean gld${EMULATION_NAME}_try_needed PARAMS ((const char *));
static void gld${EMULATION_NAME}_before_allocation PARAMS ((void));
static void gld${EMULATION_NAME}_find_statement_assignment
  PARAMS ((lang_statement_union_type *));
static void gld${EMULATION_NAME}_find_exp_assignment PARAMS ((etree_type *));
static boolean gld${EMULATION_NAME}_place_orphan
  PARAMS ((lang_input_statement_type *, asection *));
static void gld${EMULATION_NAME}_place_section
  PARAMS ((lang_statement_union_type *));
static char *gld${EMULATION_NAME}_get_script PARAMS ((int *isfile));

static void
gld${EMULATION_NAME}_before_parse()
{
  ldfile_output_architecture = bfd_arch_${ARCH};
  config.dynamic_link = ${DYNAMIC_LINK-true};
}

/* Try to open a dynamic archive.  This is where we know that ELF
   dynamic libraries have an extension of .so.  */

static boolean
gld${EMULATION_NAME}_open_dynamic_archive (arch, search, entry)
     const char *arch;
     search_dirs_type *search;
     lang_input_statement_type *entry;
{
  const char *filename;
  char *string;

  if (! entry->is_archive)
    return false;

  filename = entry->filename;

  string = (char *) xmalloc (strlen (search->name)
			     + strlen (filename)
			     + strlen (arch)
			     + sizeof "/lib.so");

  sprintf (string, "%s/lib%s%s.so", search->name, filename, arch);

  if (! ldfile_try_open_bfd (string, entry))
    {
      free (string);
      return false;
    }

  entry->filename = string;

  /* We have found a dynamic object to include in the link.  The ELF
     backend linker will create a DT_NEEDED entry in the .dynamic
     section naming this file.  If this file includes a DT_SONAME
     entry, it will be used.  Otherwise, the ELF linker will just use
     the name of the file.  For an archive found by searching, like
     this one, the DT_NEEDED entry should consist of just the name of
     the file, without the path information used to find it.  Note
     that we only need to do this if we have a dynamic object; an
     archive will never be referenced by a DT_NEEDED entry.

     FIXME: This approach--using bfd_elf_set_dt_needed_name--is not
     very pretty.  I haven't been able to think of anything that is
     pretty, though.  */
  if (bfd_check_format (entry->the_bfd, bfd_object)
      && (entry->the_bfd->flags & DYNAMIC) != 0)
    {
      char *needed_name;

      ASSERT (entry->is_archive && entry->search_dirs_flag);
      needed_name = (char *) xmalloc (strlen (filename)
				      + strlen (arch)
				      + sizeof "lib.so");
      sprintf (needed_name, "lib%s%s.so", filename, arch);
      bfd_elf_set_dt_needed_name (entry->the_bfd, needed_name);
    }

  return true;
}

/* These variables are required to pass information back and forth
   between after_open and check_needed and stat_needed.  */

static struct bfd_link_needed_list *global_needed;
static struct stat global_stat;
static boolean global_found;

/* This is called after all the input files have been opened.  */

static void
gld${EMULATION_NAME}_after_open ()
{
  struct bfd_link_needed_list *needed, *l;

  /* We only need to worry about this when doing a final link.  */
  if (link_info.relocateable || link_info.shared)
    return;

  /* Get the list of files which appear in DT_NEEDED entries in
     dynamic objects included in the link (often there will be none).
     For each such file, we want to track down the corresponding
     library, and include the symbol table in the link.  This is what
     the runtime dynamic linker will do.  Tracking the files down here
     permits one dynamic object to include another without requiring
     special action by the person doing the link.  Note that the
     needed list can actually grow while we are stepping through this
     loop.  */
  needed = bfd_elf_get_needed_list (output_bfd, &link_info);
  for (l = needed; l != NULL; l = l->next)
    {
      struct bfd_link_needed_list *ll;
      const char *lib_path;
      size_t len;
      search_dirs_type *search;

      /* If we've already seen this file, skip it.  */
      for (ll = needed; ll != l; ll = ll->next)
	if (strcmp (ll->name, l->name) == 0)
	  break;
      if (ll != l)
	continue;

      /* See if this file was included in the link explicitly.  */
      global_needed = l;
      global_found = false;
      lang_for_each_input_file (gld${EMULATION_NAME}_check_needed);
      if (global_found)
	continue;

      /* We need to find this file and include the symbol table.  We
	 want to search for the file in the same way that the dynamic
	 linker will search.  That means that we want to use
	 rpath_link, rpath, then the environment variable
	 LD_LIBRARY_PATH (native only), then the linker script
	 LIB_SEARCH_DIRS.  We do not search using the -L arguments.  */
      if (gld${EMULATION_NAME}_search_needed (command_line.rpath_link,
					      l->name))
	continue;
      if (gld${EMULATION_NAME}_search_needed (command_line.rpath, l->name))
	continue;
      if (command_line.rpath_link == NULL
	  && command_line.rpath == NULL)
	{
	  lib_path = (const char *) getenv ("LD_RUN_PATH");
	  if (gld${EMULATION_NAME}_search_needed (lib_path, l->name))
	    continue;
	}
EOF
if [ "x${host_alias}" = "x${target_alias}" ] ; then
cat >>e${EMULATION_NAME}.c <<EOF
      lib_path = (const char *) getenv ("LD_LIBRARY_PATH");
      if (gld${EMULATION_NAME}_search_needed (lib_path, l->name))
	continue;
EOF
fi
cat >>e${EMULATION_NAME}.c <<EOF
      len = strlen (l->name);
      for (search = search_head; search != NULL; search = search->next)
	{
	  char *filename;

	  if (search->cmdline)
	    continue;
	  filename = (char *) xmalloc (strlen (search->name) + len + 2);
	  sprintf (filename, "%s/%s", search->name, l->name);
	  if (gld${EMULATION_NAME}_try_needed (filename))
	    break;
	  free (filename);
	}
      if (search != NULL)
	continue;

      einfo ("%P: warning: %s, needed by %B, not found\n",
	     l->name, l->by);
    }
}

/* Search for a needed file in a path.  */

static boolean
gld${EMULATION_NAME}_search_needed (path, name)
     const char *path;
     const char *name;
{
  const char *s;
  size_t len;

  if (path == NULL || *path == '\0')
    return false;
  len = strlen (name);
  while (1)
    {
      char *filename, *sset;

      s = strchr (path, ':');
      if (s == NULL)
	s = path + strlen (path);

      filename = (char *) xmalloc (s - path + len + 2);
      if (s == path)
	sset = filename;
      else
	{
	  memcpy (filename, path, s - path);
	  filename[s - path] = '/';
	  sset = filename + (s - path) + 1;
	}
      strcpy (sset, name);

      if (gld${EMULATION_NAME}_try_needed (filename))
	return true;

      free (filename);

      if (*s == '\0')
	break;
      path = s + 1;
    }

  return false;	  
}

/* This function is called for each possible name for a dynamic object
   named by a DT_NEEDED entry.  */

static boolean
gld${EMULATION_NAME}_try_needed (name)
     const char *name;
{
  bfd *abfd;

  abfd = bfd_openr (name, bfd_get_target (output_bfd));
  if (abfd == NULL)
    return false;
  if (! bfd_check_format (abfd, bfd_object))
    {
      (void) bfd_close (abfd);
      return false;
    }
  if ((bfd_get_file_flags (abfd) & DYNAMIC) == 0)
    {
      (void) bfd_close (abfd);
      return false;
    }

  /* We've found a dynamic object matching the DT_NEEDED entry.  */

  /* We have already checked that there is no other input file of the
     same name.  We must now check again that we are not including the
     same file twice.  We need to do this because on many systems
     libc.so is a symlink to, e.g., libc.so.1.  The SONAME entry will
     reference libc.so.1.  If we have already included libc.so, we
     don't want to include libc.so.1 if they are the same file, and we
     can only check that using stat.  */

  if (bfd_stat (abfd, &global_stat) != 0)
    einfo ("%F%P:%B: bfd_stat failed: %E\n", abfd);
  global_found = false;
  lang_for_each_input_file (gld${EMULATION_NAME}_stat_needed);
  if (global_found)
    {
      /* Return true to indicate that we found the file, even though
         we aren't going to do anything with it.  */
      return true;
    }

  /* Tell the ELF backend that don't want the output file to have a
     DT_NEEDED entry for this file.  */
  bfd_elf_set_dt_needed_name (abfd, "");

  /* Add this file into the symbol table.  */
  if (! bfd_link_add_symbols (abfd, &link_info))
    einfo ("%F%B: could not read symbols: %E\n", abfd);

  return true;
}

/* See if an input file matches a DT_NEEDED entry by name.  */

static void
gld${EMULATION_NAME}_check_needed (s)
     lang_input_statement_type *s;
{
  if (s->filename != NULL
      && strcmp (s->filename, global_needed->name) == 0)
    global_found = true;
  else if (s->search_dirs_flag
	   && s->filename != NULL
	   && strchr (global_needed->name, '/') == NULL)
    {
      const char *f;

      f = strrchr (s->filename, '/');
      if (f != NULL
	  && strcmp (f + 1, global_needed->name) == 0)
	global_found = true;
    }
}

/* See if an input file matches a DT_NEEDED entry by running stat on
   the file.  */

static void
gld${EMULATION_NAME}_stat_needed (s)
     lang_input_statement_type *s;
{
  if (global_found)
    return;
  if (s->the_bfd != NULL)
    {
      struct stat st;

      if (bfd_stat (s->the_bfd, &st) != 0)
	einfo ("%P:%B: bfd_stat failed: %E\n", s->the_bfd);
      else
	{
	  if (st.st_dev == global_stat.st_dev
	      && st.st_ino == global_stat.st_ino)
	    global_found = true;
	}
    }
}

/* This is called after the sections have been attached to output
   sections, but before any sizes or addresses have been set.  */

static void
gld${EMULATION_NAME}_before_allocation ()
{
  const char *rpath;
  asection *sinterp;

  /* If we are going to make any variable assignments, we need to let
     the ELF backend know about them in case the variables are
     referred to by dynamic objects.  */
  lang_for_each_statement (gld${EMULATION_NAME}_find_statement_assignment);

  /* Let the ELF backend work out the sizes of any sections required
     by dynamic linking.  */
  rpath = command_line.rpath;
  if (rpath == NULL)
    rpath = (const char *) getenv ("LD_RUN_PATH");
  if (! bfd_elf32_size_dynamic_sections (output_bfd,
					 command_line.soname,
					 rpath,
					 command_line.export_dynamic,
					 &link_info,
					 &sinterp))
    einfo ("%P%F: failed to set dynamic section sizes: %E\n");

  /* Let the user override the dynamic linker we are using.  */
  if (command_line.interpreter != NULL
      && sinterp != NULL)
    {
      sinterp->contents = (bfd_byte *) command_line.interpreter;
      sinterp->_raw_size = strlen (command_line.interpreter) + 1;
    }

  /* Look for any sections named .gnu.warning.  As a GNU extensions,
     we treat such sections as containing warning messages.  We print
     out the warning message, and then zero out the section size so
     that it does not get copied into the output file.  */

  {
    LANG_FOR_EACH_INPUT_STATEMENT (is)
      {
	asection *s;
	bfd_size_type sz;
	char *msg;
	boolean ret;

	if (is->just_syms_flag)
	  continue;

	s = bfd_get_section_by_name (is->the_bfd, ".gnu.warning");
	if (s == NULL)
	  continue;

	sz = bfd_section_size (is->the_bfd, s);
	msg = xmalloc ((size_t) sz + 1);
	if (! bfd_get_section_contents (is->the_bfd, s, msg, (file_ptr) 0, sz))
	  einfo ("%F%B: Can't read contents of section .gnu.warning: %E\n",
		 is->the_bfd);
	msg[sz] = '\0';
	ret = link_info.callbacks->warning (&link_info, msg,
					    (const char *) NULL,
					    is->the_bfd, (asection *) NULL,
					    (bfd_vma) 0);
	ASSERT (ret);
	free (msg);

	/* Clobber the section size, so that we don't waste copying the
	   warning into the output file.  */
	s->_raw_size = 0;
      }
  }

#if defined (TARGET_IS_elf32bmip) || defined (TARGET_IS_elf32lmip)
  /* For MIPS ELF the .reginfo section requires special handling.
     Each input section is 24 bytes, and the final output section must
     also be 24 bytes.  We handle this by clobbering all but the first
     input section size to 0.  The .reginfo section is handled
     specially by the backend code anyhow.  */
  {
    boolean found = false;
    LANG_FOR_EACH_INPUT_STATEMENT (is)
      {
	asection *s;

	if (is->just_syms_flag)
	  continue;

	s = bfd_get_section_by_name (is->the_bfd, ".reginfo");
	if (s == NULL)
	  continue;

	if (! found)
	  {
	    found = true;
	    continue;
	  }

	s->_raw_size = 0;
	s->_cooked_size = 0;
      }
  }
#endif
}

/* This is called by the before_allocation routine via
   lang_for_each_statement.  It locates any assignment statements, and
   tells the ELF backend about them, in case they are assignments to
   symbols which are referred to by dynamic objects.  */

static void
gld${EMULATION_NAME}_find_statement_assignment (s)
     lang_statement_union_type *s;
{
  if (s->header.type == lang_assignment_statement_enum)
    gld${EMULATION_NAME}_find_exp_assignment (s->assignment_statement.exp);
}

/* Look through an expression for an assignment statement.  */

static void
gld${EMULATION_NAME}_find_exp_assignment (exp)
     etree_type *exp;
{
  struct bfd_link_hash_entry *h;

  switch (exp->type.node_class)
    {
    case etree_provide:
      h = bfd_link_hash_lookup (link_info.hash, exp->assign.dst,
				false, false, false);
      if (h == NULL)
	break;

      /* We call record_link_assignment even if the symbol is defined.
	 This is because if it is defined by a dynamic object, we
	 actually want to use the value defined by the linker script,
	 not the value from the dynamic object (because we are setting
	 symbols like etext).  If the symbol is defined by a regular
	 object, then, as it happens, calling record_link_assignment
	 will do no harm.  */

      /* Fall through.  */
    case etree_assign:
      if (strcmp (exp->assign.dst, ".") != 0)
	{
	  if (! (bfd_elf32_record_link_assignment
		 (output_bfd, &link_info, exp->assign.dst,
		  exp->type.node_class == etree_provide ? true : false)))
	    einfo ("%P%F: failed to record assignment to %s: %E\n",
		   exp->assign.dst);
	}
      gld${EMULATION_NAME}_find_exp_assignment (exp->assign.src);
      break;

    case etree_binary:
      gld${EMULATION_NAME}_find_exp_assignment (exp->binary.lhs);
      gld${EMULATION_NAME}_find_exp_assignment (exp->binary.rhs);
      break;

    case etree_trinary:
      gld${EMULATION_NAME}_find_exp_assignment (exp->trinary.lhs);
      gld${EMULATION_NAME}_find_exp_assignment (exp->trinary.lhs);
      gld${EMULATION_NAME}_find_exp_assignment (exp->trinary.rhs);
      break;

    case etree_unary:
      gld${EMULATION_NAME}_find_exp_assignment (exp->unary.child);
      break;

    default:
      break;
    }
}

/* Place an orphan section.  We use this to put random SHF_ALLOC
   sections in the right segment.  */

static asection *hold_section;
static lang_output_section_statement_type *hold_use;
static lang_output_section_statement_type *hold_text;
static lang_output_section_statement_type *hold_data;
static lang_output_section_statement_type *hold_bss;
static lang_output_section_statement_type *hold_rel;

/*ARGSUSED*/
static boolean
gld${EMULATION_NAME}_place_orphan (file, s)
     lang_input_statement_type *file;
     asection *s;
{
  lang_output_section_statement_type *place;
  asection *snew, **pps;
  lang_statement_list_type *old;
  lang_statement_list_type add;
  etree_type *address;
  const char *secname, *ps;
  lang_output_section_statement_type *os;

  if ((s->flags & SEC_ALLOC) == 0)
    return false;

  /* Look through the script to see where to place this section.  */
  hold_section = s;
  hold_use = NULL;
  lang_for_each_statement (gld${EMULATION_NAME}_place_section);

  if (hold_use != NULL)
    {
      /* We have already placed a section with this name.  */
      wild_doit (&hold_use->children, s, hold_use, file);
      return true;
    }

  secname = bfd_get_section_name (s->owner, s);

  /* If this is a final link, then always put .gnu.warning.SYMBOL
     sections into the .text section to get them out of the way.  */
  if (! link_info.shared
      && ! link_info.relocateable
      && strncmp (secname, ".gnu.warning.", sizeof ".gnu.warning." - 1) == 0
      && hold_text != NULL)
    {
      wild_doit (&hold_text->children, s, hold_text, file);
      return true;
    }

  /* Decide which segment the section should go in based on the
     section name and section flags.  */
  place = NULL;
  if ((s->flags & SEC_HAS_CONTENTS) == 0
      && hold_bss != NULL)
    place = hold_bss;
  else if ((s->flags & SEC_READONLY) == 0
	   && hold_data != NULL)
    place = hold_data;
  else if (strncmp (secname, ".rel", 4) == 0
	   && hold_rel != NULL)
    place = hold_rel;
  else if ((s->flags & SEC_READONLY) != 0
	   && hold_text != NULL)
    place = hold_text;
  if (place == NULL)
    return false;

  /* Create the section in the output file, and put it in the right
     place.  This shuffling is to make the output file look neater.  */
  snew = bfd_make_section (output_bfd, secname);
  if (snew == NULL)
      einfo ("%P%F: output format %s cannot represent section called %s\n",
	     output_bfd->xvec->name, secname);
  if (place->bfd_section != NULL)
    {
      for (pps = &output_bfd->sections; *pps != snew; pps = &(*pps)->next)
	;
      *pps = snew->next;
      snew->next = place->bfd_section->next;
      place->bfd_section->next = snew;
    }

  /* Start building a list of statements for this section.  */
  old = stat_ptr;
  stat_ptr = &add;
  lang_list_init (stat_ptr);

  /* If the name of the section is representable in C, then create
     symbols to mark the start and the end of the section.  */
  for (ps = secname; *ps != '\0'; ps++)
    if (! isalnum (*ps) && *ps != '_')
      break;
  if (*ps == '\0' && config.build_constructors)
    {
      char *symname;

      symname = (char *) xmalloc (ps - secname + sizeof "__start_");
      sprintf (symname, "__start_%s", secname);
      lang_add_assignment (exp_assop ('=', symname,
				      exp_nameop (NAME, ".")));
    }

  if (! link_info.relocateable)
    address = NULL;
  else
    address = exp_intop ((bfd_vma) 0);

  lang_enter_output_section_statement (secname, address, 0,
				       (bfd_vma) 0,
				       (etree_type *) NULL,
				       (etree_type *) NULL,
				       (etree_type *) NULL);

  os = lang_output_section_statement_lookup (secname);
  wild_doit (&os->children, s, os, file);

  lang_leave_output_section_statement ((bfd_vma) 0, "*default*");
  stat_ptr = &add;

  if (*ps == '\0' && config.build_constructors)
    {
      char *symname;

      symname = (char *) xmalloc (ps - secname + sizeof "__stop_");
      sprintf (symname, "__stop_%s", secname);
      lang_add_assignment (exp_assop ('=', symname,
				      exp_nameop (NAME, ".")));
    }

  /* Now stick the new statement list right after PLACE.  */
  *add.tail = place->header.next;
  place->header.next = add.head;

  stat_ptr = old;

  return true;
}

static void
gld${EMULATION_NAME}_place_section (s)
     lang_statement_union_type *s;
{
  lang_output_section_statement_type *os;

  if (s->header.type != lang_output_section_statement_enum)
    return;

  os = &s->output_section_statement;

  if (strcmp (os->name, hold_section->name) == 0)
    hold_use = os;

  if (strcmp (os->name, ".text") == 0)
    hold_text = os;
  else if (strcmp (os->name, ".data") == 0)
    hold_data = os;
  else if (strcmp (os->name, ".bss") == 0)
    hold_bss = os;
  else if (hold_rel == NULL
	   && strncmp (os->name, ".rel", 4) == 0)
    hold_rel = os;
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
  else if (link_info.shared)
    return `sed "$sc" ldscripts/${EMULATION_NAME}.xs`;
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
  else if (link_info.shared)
    return "ldscripts/${EMULATION_NAME}.xs";
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
  gld${EMULATION_NAME}_after_open,
  after_allocation_default,
  set_output_arch_default,
  ldemul_default_target,
  gld${EMULATION_NAME}_before_allocation,
  gld${EMULATION_NAME}_get_script,
  "${EMULATION_NAME}",
  "${OUTPUT_FORMAT}",
  NULL,
  NULL,
  gld${EMULATION_NAME}_open_dynamic_archive,
  gld${EMULATION_NAME}_place_orphan
};
EOF