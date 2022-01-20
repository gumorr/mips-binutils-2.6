/* This file is is generated by a shell script.  DO NOT EDIT! */

/* AIX emulation code for ppcmacos
   Copyright (C) 1991, 1993, 1995 Free Software Foundation, Inc.
   Written by Steve Chamberlain <sac@cygnus.com>
   AIX support by Ian Lance Taylor <ian@cygnus.com>

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

#define TARGET_IS_ppcmacos

#include "bfd.h"
#include "sysdep.h"
#include "libiberty.h"
#include "getopt.h"
#include "bfdlink.h"

#include <ctype.h>

#include "ld.h"
#include "ldmain.h"
#include "ldemul.h"
#include "ldfile.h"
#include "ldmisc.h"
#include "ldexp.h"
#include "ldlang.h"

static void gldppcmacos_before_parse PARAMS ((void));
static int gldppcmacos_parse_args PARAMS ((int, char **));
static void gldppcmacos_before_allocation PARAMS ((void));
static void gldppcmacos_read_file PARAMS ((const char *, boolean));
static void gldppcmacos_free PARAMS ((PTR));
static char *gldppcmacos_get_script PARAMS ((int *isfile));

/* The file alignment required for each section.  */
static unsigned long file_align;

/* The maximum size the stack is permitted to grow.  This is stored in
   the a.out header.  */
static unsigned long maxstack;

/* The maximum data size.  This is stored in the a.out header.  */
static unsigned long maxdata;

/* Whether to perform garbage collection.  */
static int gc = 1;

/* The module type to use.  */
static unsigned short modtype = ('1' << 8) | 'L';

/* Whether the .text section must be read-only (i.e., no relocs
   permitted).  */
static int textro;

/* Structure used to hold import or export file list.  */

struct filelist
{
  struct filelist *next;
  const char *name;
};

/* List of import files.  */
struct filelist *import_files;

/* List of export files.  */
struct filelist *export_files;

static void
gldppcmacos_before_parse()
{
#ifndef TARGET_			/* I.e., if not generic.  */
  ldfile_output_architecture = bfd_arch_powerpc;
#endif /* not TARGET_ */
}

/* Handle AIX specific options.  */

static int
gldppcmacos_parse_args (argc, argv)
     int argc;
     char **argv;
{
  int prevoptind = optind;
  int prevopterr = opterr;
  int longind;
  int optc;
  long val;
  char *end;

#define OPTION_IGNORE (300)
#define OPTION_AUTOIMP (OPTION_IGNORE + 1)
#define OPTION_ERNOTOK (OPTION_AUTOIMP + 1)
#define OPTION_EROK (OPTION_ERNOTOK + 1)
#define OPTION_EXPORT (OPTION_EROK + 1)
#define OPTION_IMPORT (OPTION_EXPORT + 1)
#define OPTION_MAXDATA (OPTION_IMPORT + 1)
#define OPTION_MAXSTACK (OPTION_MAXDATA + 1)
#define OPTION_MODTYPE (OPTION_MAXSTACK + 1)
#define OPTION_NOAUTOIMP (OPTION_MODTYPE + 1)
#define OPTION_NOSTRCMPCT (OPTION_NOAUTOIMP + 1)
#define OPTION_STRCMPCT (OPTION_NOSTRCMPCT + 1)

  static struct option longopts[] = {
    {"basis", no_argument, NULL, OPTION_IGNORE},
    {"bautoimp", no_argument, NULL, OPTION_AUTOIMP},
    {"bcomprld", no_argument, NULL, OPTION_IGNORE},
    {"bcrld", no_argument, NULL, OPTION_IGNORE},
    {"bcror31", no_argument, NULL, OPTION_IGNORE},
    {"bD", required_argument, NULL, OPTION_MAXDATA},
    {"bE", required_argument, NULL, OPTION_EXPORT},
    {"bernotok", no_argument, NULL, OPTION_ERNOTOK},
    {"berok", no_argument, NULL, OPTION_EROK},
    {"berrmsg", no_argument, NULL, OPTION_IGNORE},
    {"bexport", required_argument, NULL, OPTION_EXPORT},
    {"bf", no_argument, NULL, OPTION_ERNOTOK},
    {"bgc", no_argument, &gc, 1},
    {"bh", required_argument, NULL, OPTION_IGNORE},
    {"bhalt", required_argument, NULL, OPTION_IGNORE},
    {"bI", required_argument, NULL, OPTION_IMPORT},
    {"bimport", required_argument, NULL, OPTION_IMPORT},
    {"bmaxdata", required_argument, NULL, OPTION_MAXDATA},
    {"bmaxstack", required_argument, NULL, OPTION_MAXSTACK},
    {"bM", required_argument, NULL, OPTION_MODTYPE},
    {"bmodtype", required_argument, NULL, OPTION_MODTYPE},
    {"bnoautoimp", no_argument, NULL, OPTION_NOAUTOIMP},
    {"bnodelcsect", no_argument, NULL, OPTION_IGNORE},
    {"bnogc", no_argument, &gc, 0},
    {"bnso", no_argument, NULL, OPTION_NOAUTOIMP},
    {"bnostrcmpct", no_argument, NULL, OPTION_NOSTRCMPCT},
    {"bnotextro", no_argument, &textro, 0},
    {"bnro", no_argument, &textro, 0},
    {"bro", no_argument, &textro, 1},
    {"bS", required_argument, NULL, OPTION_MAXSTACK},
    {"bso", no_argument, NULL, OPTION_AUTOIMP},
    {"bstrcmpct", no_argument, NULL, OPTION_STRCMPCT},
    {"btextro", no_argument, &textro, 1},
    {NULL, no_argument, NULL, 0}
  };

  /* Options supported by the AIX linker which we do not support: -f,
     -S, -v, -Z, -bbindcmds, -bbinder, -bbindopts, -bcalls, -bcaps,
     -bcror15, -bdebugopt, -bdbg, -bdelcsect, -bex?, -bfilelist, -bfl,
     -bgcbypass, -bglink, -binsert, -bi, -bloadmap, -bl, -bmap, -bnl,
     -bnobind, -bnocomprld, -bnocrld, -bnoerrmsg, -bnoglink,
     -bnoloadmap, -bnl, -bnoobjreorder, -bnoquiet, -bnoreorder,
     -bnotypchk, -bnox, -bquiet, -bR, -brename, -breorder, -btypchk,
     -bx, -bX, -bxref.  */

  /* If the first option starts with -b, change the first : to an =.
     The AIX linker uses : to separate the option from the argument;
     changing it to = lets us treat it as a getopt option.  */
  if (optind < argc && strncmp (argv[optind], "-b", 2) == 0)
    {
      char *s;

      for (s = argv[optind]; *s != '\0'; s++)
	{
	  if (*s == ':')
	    {
	      *s = '=';
	      break;
	    }
	}
    }

  opterr = 0;
  optc = getopt_long_only (argc, argv, "-D:H:KT:z", longopts, &longind);
  opterr = prevopterr;

  switch (optc)
    {
    default:
      optind = prevoptind;
      return 0;

    case 0:
      /* Long option which just sets a flag.  */
      break;

    case 'D':
      val = strtol (optarg, &end, 0);
      if (*end != '\0')
	einfo ("%P: warning: ignoring invalid -D number %s\n", optarg);
      else if (val != -1)
	lang_section_start (".data", exp_intop (val));
      break;

    case 'H':
      val = strtoul (optarg, &end, 0);
      if (*end != '\0'
	  || (val & (val - 1)) != 0)
	einfo ("%P: warning: ignoring invalid -H number %s\n", optarg);
      else
	file_align = val;
      break;

    case 'K':
    case 'z':
      /* FIXME: This should use the page size for the target system.  */
      file_align = 4096;
      break;

    case 'T':
      /* On AIX this is the same as GNU ld -Ttext.  When we see -T
         number, we assume the AIX option is intended.  Otherwise, we
         assume the usual GNU ld -T option is intended.  We can't just
         ignore the AIX option, because gcc passes it to the linker.  */
      val = strtoul (optarg, &end, 0);
      if (*end != '\0')
	{
	  optind = prevoptind;
	  return 0;
	}
      lang_section_start (".text", exp_intop (val));
      break;

    case OPTION_IGNORE:
      break;

    case OPTION_AUTOIMP:
      link_info.static_link = false;
      break;

    case OPTION_ERNOTOK:
      force_make_executable = false;
      break;

    case OPTION_EROK:
      force_make_executable = true;
      break;

    case OPTION_EXPORT:
    case OPTION_IMPORT:
      {
	struct filelist *n;
	struct filelist **flpp;

	n = (struct filelist *) xmalloc (sizeof (struct filelist));
	n->next = NULL;
	n->name = optarg;
	if (optc == OPTION_EXPORT)
	  flpp = &export_files;
	else
	  flpp = &import_files;
	while (*flpp != NULL)
	  flpp = &(*flpp)->next;
	*flpp = n;
      }
      break;

    case OPTION_MAXDATA:
      val = strtoul (optarg, &end, 0);
      if (*end != '\0')
	einfo ("%P: warning: ignoring invalid -bmaxdata number %s\n",
	       optarg);
      else
	maxdata = val;
      break;

    case OPTION_MAXSTACK:
      val = strtoul (optarg, &end, 0);
      if (*end != '\0')
	einfo ("%P: warning: ignoring invalid -bmaxstack number %s\n",
	       optarg);
      else
	maxstack = val;
      break;

    case OPTION_MODTYPE:
      if (*optarg == 'S')
	{
	  link_info.shared = true;
	  ++optarg;
	}
      if (*optarg == '\0' || optarg[1] == '\0')
	einfo ("%P: warning: ignoring invalid module type %s\n", optarg);
      else
	modtype = (*optarg << 8) | optarg[1];
      break;

    case OPTION_NOAUTOIMP:
      link_info.static_link = true;
      break;

    case OPTION_NOSTRCMPCT:
      config.traditional_format = true;
      break;

    case OPTION_STRCMPCT:
      config.traditional_format = false;
      break;
    }

  return 1;
}

/* This is called after the sections have been attached to output
   sections, but before any sizes or addresses have been set.  */

static void
gldppcmacos_before_allocation ()
{
  struct filelist *fl;
  char *libpath;

  /* Handle the import and export files, if any.  */
  for (fl = import_files; fl != NULL; fl = fl->next)
    gldppcmacos_read_file (fl->name, true);
  for (fl = export_files; fl != NULL; fl = fl->next)
    gldppcmacos_read_file (fl->name, false);

  /* We need to build LIBPATH from the -L arguments.  If any -rpath
     arguments were used, though, we use -rpath instead, as a GNU
     extension.  */
  if (command_line.rpath != NULL)
    libpath = command_line.rpath;
  else if (search_head == NULL)
    libpath = (char *) "";
  else
    {
      size_t len;
      search_dirs_type *search;

      len = strlen (search_head->name);
      libpath = xmalloc (len + 1);
      strcpy (libpath, search_head->name);
      for (search = search_head->next; search != NULL; search = search->next)
	{
	  size_t nlen;

	  nlen = strlen (search->name);
	  libpath = xrealloc (libpath, len + nlen + 2);
	  libpath[len] = ':';
	  strcpy (libpath + len + 1, search->name);
	  len += nlen + 1;
	}
    }

  /* Let the XCOFF backend set up the .loader section.  */
  if (! bfd_xcoff_size_dynamic_sections (output_bfd, &link_info, libpath,
					 entry_symbol, file_align,
					 maxstack, maxdata,
					 gc ? true : false,
					 modtype,
					 textro ? true : false))
    einfo ("%P%F: failed to set dynamic section sizes: %E\n");
}

/* Read an import or export file.  */

static void
gldppcmacos_read_file (filename, import)
     const char *filename;
     boolean import;
{
  struct obstack *o;
  FILE *f;
  int lineno;
  int c;
  boolean keep;
  const char *imppath;
  const char *impfile;
  const char *impmember;

  o = (struct obstack *) xmalloc (sizeof (struct obstack));
  obstack_specify_allocation (o, 0, 0, xmalloc, gldppcmacos_free);

  f = fopen (filename, "r");
  if (f == NULL)
    {
      bfd_set_error (bfd_error_system_call);
      einfo ("%F%s: %E\n", filename);
    }

  keep = false;

  imppath = NULL;
  impfile = NULL;
  impmember = NULL;

  lineno = 0;
  while ((c = getc (f)) != EOF)
    {
      char *s;
      char *symname;
      boolean syscall;
      bfd_vma address;
      struct bfd_link_hash_entry *h;

      if (c != '\n')
	{
	  obstack_1grow (o, c);
	  continue;
	}

      obstack_1grow (o, '\0');
      ++lineno;

      s = (char *) obstack_base (o);
      while (isspace ((unsigned char) *s))
	++s;
      if (*s == '\0'
	  || *s == '*'
	  || (*s == '#' && s[1] == ' ')
	  || (! import && *s == '#' && s[1] == '!'))
	{
	  obstack_free (o, obstack_base (o));
	  continue;
	}

      if (*s == '#' && s[1] == '!')
	{
	  s += 2;
	  while (isspace ((unsigned char) *s))
	    ++s;
	  if (*s == '\0')
	    {
	      imppath = NULL;
	      impfile = NULL;
	      impmember = NULL;
	      obstack_free (o, obstack_base (o));
	    }
	  else if (*s == '(')
	    einfo ("%F%s%d: #! ([member]) is not supported in import files",
		   filename, lineno);
	  else
	    {
	      char cs;
	      char *file;

	      (void) obstack_finish (o);
	      keep = true;
	      imppath = s;
	      impfile = NULL;
	      while (! isspace ((unsigned char) *s) && *s != '(' && *s != '\0')
		{
		  if (*s == '/')
		    file = s + 1;
		  ++s;
		}
	      if (file != NULL)
		{
		  file[-1] = '\0';
		  impfile = file;
		  if (imppath == file - 1)
		    imppath = "/";
		}
	      else
		{
		  impfile = imppath;
		  imppath = "";
		}
	      cs = *s;
	      *s = '\0';
	      while (isspace ((unsigned char) cs))
		{
		  ++s;
		  cs = *s;
		}
	      if (cs != '(')
		{
		  impmember = "";
		  if (cs != '\0')
		    einfo ("%s:%d: warning: syntax error in import file\n",
			   filename, lineno);
		}
	      else
		{
		  ++s;
		  impmember = s;
		  while (*s != ')' && *s != '\0')
		    ++s;
		  if (*s == ')')
		    *s = '\0';
		  else
		    einfo ("%s:%d: warning: syntax error in import file\n",
			   filename, lineno);
		}
	    }

	  continue;
	}

      /* This is a symbol to be imported or exported.  */
      symname = s;
      syscall = false;
      address = (bfd_vma) -1;

      while (! isspace ((unsigned char) *s) && *s != '\0')
	++s;
      if (*s != '\0')
	{
	  char *se;

	  *s++ = '\0';

	  while (isspace ((unsigned char) *s))
	    ++s;

	  se = s;
	  while (! isspace ((unsigned char) *se) && *se != '\0')
	    ++se;
	  if (*se != '\0')
	    {
	      *se++ = '\0';
	      while (isspace ((unsigned char) *se))
		++se;
	      if (*se != '\0')
		einfo ("%s%d: warning: syntax error in import/export file\n",
		       filename, lineno);
	    }

	  if (strcasecmp (s, "svc") == 0
	      || strcasecmp (s, "syscall") == 0)
	    syscall = true;
	  else
	    {
	      char *end;

	      address = strtoul (s, &end, 0);
	      if (*end != '\0')
		einfo ("%s:%d: warning: syntax error in import/export file\n",
		       filename, lineno);
	    }
	}

      h = bfd_link_hash_lookup (link_info.hash, symname, false, false, true);
      if (h == NULL || h->type == bfd_link_hash_new)
	{
	  /* We can just ignore attempts to import an unreferenced
	     symbol.  */
	  if (! import)
	    einfo ("%X%s:%d: attempt to export undefined symbol %s\n",
		   filename, lineno, symname);
	}
      else if (import)
	{
	  if (! bfd_xcoff_import_symbol (output_bfd, &link_info, h, address,
					 imppath, impfile, impmember))
	    einfo ("%X%s:%d: failed to import symbol %s: %E\n",
		   filename, lineno, symname);
	}
      else
	{
	  if (! bfd_xcoff_export_symbol (output_bfd, &link_info, h, syscall))
	    einfo ("%X%s:%d: failed to export symbol %s: %E\n",
		   filename, lineno, symname);
	}

      obstack_free (o, obstack_base (o));
    }

  if (obstack_object_size (o) > 0)
    {
      einfo ("%s:%d: warning: ignoring unterminated last line\n",
	     filename, lineno);
      obstack_free (o, obstack_base (o));
    }

  if (! keep)
    {
      obstack_free (o, NULL);
      free (o);
    }
}

/* This routine saves us from worrying about declaring free.  */

static void
gldppcmacos_free (p)
     PTR p;
{
  free (p);
}

static char *
gldppcmacos_get_script(isfile)
     int *isfile;
{			     
  *isfile = 0;

  if (link_info.relocateable == true && config.build_constructors == true)
    return
"OUTPUT_FORMAT(\"xcoff-powermac\")\n\
OUTPUT_ARCH(powerpc)\n\
ENTRY(__start)\n\
SECTIONS\n\
{\n\
  .pad 0 : { *(.pad) }\n\
  .text 0 : {\n\
    *(.text)\n\
    *(.pr)\n\
    *(.ro)\n\
    *(.db)\n\
    *(.gl)\n\
    *(.xo)\n\
    *(.ti)\n\
    *(.tb)\n\
  }\n\
  .data 0 : {\n\
    *(.data)\n\
    *(.rw)\n\
    *(.sv)\n\
    *(.ua)\n\
    *(.ds)\n\
    *(.tc0)\n\
    *(.tc)\n\
    *(.td)\n\
  }\n\
  .bss : {\n\
    *(.bss)\n\
    *(.bs)\n\
    *(.uc)\n\
    *(COMMON)\n\
  }\n\
  .loader 0 : {\n\
    *(.loader)\n\
  }\n\
  .debug 0 : {\n\
    *(.debug)\n\
  }\n\
}\n\n"
  ; else if (link_info.relocateable == true) return
"OUTPUT_FORMAT(\"xcoff-powermac\")\n\
OUTPUT_ARCH(powerpc)\n\
ENTRY(__start)\n\
SECTIONS\n\
{\n\
  .pad 0 : { *(.pad) }\n\
  .text 0 : {\n\
    *(.text)\n\
    *(.pr)\n\
    *(.ro)\n\
    *(.db)\n\
    *(.gl)\n\
    *(.xo)\n\
    *(.ti)\n\
    *(.tb)\n\
  }\n\
  .data 0 : {\n\
    *(.data)\n\
    *(.rw)\n\
    *(.sv)\n\
    *(.ua)\n\
    *(.ds)\n\
    *(.tc0)\n\
    *(.tc)\n\
    *(.td)\n\
  }\n\
  .bss : {\n\
    *(.bss)\n\
    *(.bs)\n\
    *(.uc)\n\
    *(COMMON)\n\
  }\n\
  .loader 0 : {\n\
    *(.loader)\n\
  }\n\
  .debug 0 : {\n\
    *(.debug)\n\
  }\n\
}\n\n"
  ; else if (!config.text_read_only) return
"OUTPUT_FORMAT(\"xcoff-powermac\")\n\
OUTPUT_ARCH(powerpc)\n\
 SEARCH_DIR(/usr/local/powerpc-apple-macos/lib);\n\
ENTRY(__start)\n\
SECTIONS\n\
{\n\
  .pad 0 : { *(.pad) }\n\
  .text   : {\n\
    PROVIDE (_text = .);\n\
    *(.text)\n\
    *(.pr)\n\
    *(.ro)\n\
    *(.db)\n\
    *(.gl)\n\
    *(.xo)\n\
    *(.ti)\n\
    *(.tb)\n\
    PROVIDE (_etext = .);\n\
  }\n\
  .data 0 : {\n\
    PROVIDE (_data = .);\n\
    *(.data)\n\
    *(.rw)\n\
    *(.sv)\n\
    *(.ua)\n\
    *(.ds)\n\
    *(.tc0)\n\
    *(.tc)\n\
    *(.td)\n\
    PROVIDE (_edata = .);\n\
  }\n\
  .bss : {\n\
    *(.bss)\n\
    *(.bs)\n\
    *(.uc)\n\
    *(COMMON)\n\
    PROVIDE (_end = .);\n\
    PROVIDE (end = .);\n\
  }\n\
  .loader 0 : {\n\
    *(.loader)\n\
  }\n\
  .debug 0 : {\n\
    *(.debug)\n\
  }\n\
}\n\n"
  ; else if (!config.magic_demand_paged) return
"OUTPUT_FORMAT(\"xcoff-powermac\")\n\
OUTPUT_ARCH(powerpc)\n\
 SEARCH_DIR(/usr/local/powerpc-apple-macos/lib);\n\
ENTRY(__start)\n\
SECTIONS\n\
{\n\
  .pad 0 : { *(.pad) }\n\
  .text   : {\n\
    PROVIDE (_text = .);\n\
    *(.text)\n\
    *(.pr)\n\
    *(.ro)\n\
    *(.db)\n\
    *(.gl)\n\
    *(.xo)\n\
    *(.ti)\n\
    *(.tb)\n\
    PROVIDE (_etext = .);\n\
  }\n\
  .data 0 : {\n\
    PROVIDE (_data = .);\n\
    *(.data)\n\
    *(.rw)\n\
    *(.sv)\n\
    *(.ua)\n\
    *(.ds)\n\
    *(.tc0)\n\
    *(.tc)\n\
    *(.td)\n\
    PROVIDE (_edata = .);\n\
  }\n\
  .bss : {\n\
    *(.bss)\n\
    *(.bs)\n\
    *(.uc)\n\
    *(COMMON)\n\
    PROVIDE (_end = .);\n\
    PROVIDE (end = .);\n\
  }\n\
  .loader 0 : {\n\
    *(.loader)\n\
  }\n\
  .debug 0 : {\n\
    *(.debug)\n\
  }\n\
}\n\n"
  ; else return
"OUTPUT_FORMAT(\"xcoff-powermac\")\n\
OUTPUT_ARCH(powerpc)\n\
 SEARCH_DIR(/usr/local/powerpc-apple-macos/lib);\n\
ENTRY(__start)\n\
SECTIONS\n\
{\n\
  .pad 0 : { *(.pad) }\n\
  .text   : {\n\
    PROVIDE (_text = .);\n\
    *(.text)\n\
    *(.pr)\n\
    *(.ro)\n\
    *(.db)\n\
    *(.gl)\n\
    *(.xo)\n\
    *(.ti)\n\
    *(.tb)\n\
    PROVIDE (_etext = .);\n\
  }\n\
  .data 0 : {\n\
    PROVIDE (_data = .);\n\
    *(.data)\n\
    *(.rw)\n\
    *(.sv)\n\
    *(.ua)\n\
    *(.ds)\n\
    *(.tc0)\n\
    *(.tc)\n\
    *(.td)\n\
    PROVIDE (_edata = .);\n\
  }\n\
  .bss : {\n\
    *(.bss)\n\
    *(.bs)\n\
    *(.uc)\n\
    *(COMMON)\n\
    PROVIDE (_end = .);\n\
    PROVIDE (end = .);\n\
  }\n\
  .loader 0 : {\n\
    *(.loader)\n\
  }\n\
  .debug 0 : {\n\
    *(.debug)\n\
  }\n\
}\n\n"
; }

struct ld_emulation_xfer_struct ld_ppcmacos_emulation = 
{
  gldppcmacos_before_parse,
  syslib_default,
  hll_default,
  after_parse_default,
  after_open_default,
  after_allocation_default,
  set_output_arch_default,
  ldemul_default_target,
  gldppcmacos_before_allocation,
  gldppcmacos_get_script,
  "ppcmacos",
  "xcoff-powermac",
  0,	/* finish */
  0,	/* create_output_section_statements */
  0,	/* open_dynamic_archive */
  0,	/* place_orphan */
  0,	/* set_symbols */
  gldppcmacos_parse_args,
};