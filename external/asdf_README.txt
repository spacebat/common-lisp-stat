$Id: README,v 1.39 2006/08/21 10:52:32 crhodes Exp $         -*- Text -*-

The canonical documentation for asdf is in the file asdf.texinfo.  
The significant overlap between this file and that will one day be
resolved by deleting text from this file; in the meantime, please look
there before here.



asdf: another system definition facility          
========================================

* Getting the latest version

0) Decide which version you want.  HEAD is the newest version and
usually OK, whereas RELEASE is for cautious people (e.g. who already
have systems using asdf that they don't want broken), a slightly older
version about which none of the HEAD users have complained.

1) Check it out from sourceforge cCLan CVS:

1a) cvs -d:pserver:anonymous@cvs.cclan.sourceforge.net:/cvsroot/cclan login
     (no password: just press Enter)
 
1a.1) cvs -z3 -d:pserver:anonymous@cvs.cclan.sourceforge.net:/cvsroot/cclan
         co -r RELEASE asdf

or for the bleeding edge, instead

1a.2) cvs -z3 -d:pserver:anonymous@cvs.cclan.sourceforge.net:/cvsroot/cclan
          co -A asdf

If you are tracking the bleeding edge, you may want to subscribe to
the cclan-commits mailing list (see
<URL:http://sourceforge.net/mail/?group_id=28536>) to receive commit
messages and diffs whenever changes are made.

For more CVS information, look at http://sourceforge.net/cvs/?group_id=28536


* Getting started

- The single file asdf.lisp is all you need to use asdf normally.  For
maximum convenience you want to have it loaded whenever you start your
Lisp implementation, by loading it from the startup script, or dumping
a custom core, or something.

- The variable asdf:*central-registry* is a list of system directory
  designators.  A system directory designator is a form which will be
  evaluated whenever a system is to be found, and must evaluate to a
  directory to look in.  For example, you might have

     (*default-pathname-defaults* "/home/me/cl/systems/"
      "/usr/share/common-lisp/systems/")

  (When we say "directory" here, we mean "designator for a pathname
  with a supplied DIRECTORY component")

  It is possible to customize the system definition file search.
  That's considered advanced use, and covered later: search forward
  for *system-definition-search-functions*

- To compile and load a system 'foo', you need to (1) ensure that
  foo.asd is in one of the directories in *central-registry* (a
  symlink to the real location of foo.asd is preferred), (2) execute
  ``(asdf:operate 'asdf:load-op 'foo)''

    $ cd /home/me/cl/systems/
    $ ln -s ~/src/foo/foo.asd .
    $ lisp
    * (asdf:operate 'asdf:load-op 'foo)

- To write your own system definitions, look at the test systems in
  test/ , and read the rest of this.  Ignore systems/ which is old
  and may go away when next I clean up

- Syntax is similar to mk-defsystem 3 for straightforward systems, you
  may only need to remove the :source-pathname option (and replace it
  with :pathname if the asd file is not in the same place as the
  system sources)

- Join cclan-list@lists.sf.net for discussion, bug reports, questions, etc

- cclan.asd and the source files listed therein contain useful extensions 
  for maintainers of systems in the cCLan.  If this isn't you, you
  don't need them - although you may want to look at them anyway

- For systems that do complicated things (e.g. compiling C files to
  load as foreign code), the packages in vn-cclan may provide some
  guidance.  db-sockets, for example, is known to do outlandish things
  with preprocessors

   http://ww.telent.net/cliki/vn-cclan 



* Concepts

This system definition utility talks in terms of 'components' and
'operations'.

Components form systems: a component represents a source file, or a
collection of components.  A system is therefore a component,
recursively formed of a tree of subcomponents.

Operations are instantiated then performed on the nodes of a tree to
do things like

 - compile all its files
 - load the files into a running lisp environment
 - copy its source files somewhere else

Operations can be invoked directly, or examined to see what their
effects would be without performing them.  There are a bunch of 
methods specialised on operation and component type which actually do
the grunt work.

asdf is extensible to new operations and to new component types.  This
allows the addition of behaviours: for example, a new component could
be added for Java JAR archives, and methods specialised on compile-op
added for it that would accomplish the relevant actions.  Users
defining their own operations and component types should inherit from
the asdf base classes asdf:operation and asdf:component respectively.

* Inspiration

** mk-defsystem (defsystem-3.x)

We aim to solve basically the same problems as mk-defsystem does.
However, our architecture for extensibility better exploits CL
language features (and is documented), and we intend to be portable
rather than just widely-ported.  No slight on the mk-defsystem authors
and maintainers is intended here; that implementation has the
unenviable task of supporting non-ANSI implementations, which I
propose to ignore.

The surface defsystem syntax of asdf is more-or-less compatible with
mk-defsystem

The mk-defsystem code for topologically sorting a module's dependency
list was very useful.

** defsystem-4 proposal

Marco and Peter's proposal for defsystem 4 served as the driver for
many of the features in here.  Notable differences are

- we don't specify output files or output file extensions as part of
  the system

  If you want to find out what files an operation would create, ask
  the operation

- we don't deal with CL packages

  If you want to compile in a particular package, use an in-package
  form in that file (ilisp will like you more if you do this anyway)

- there is no proposal here that defsystem does version control.  

  A system has a given version which can be used to check
  dependencies, but that's all.

The defsystem 4 proposal tends to look more at the external features,
whereas this one centres on a protocol for system introspection.

** kmp's "The Description of Large Systems", MIT AI Memu 801

Available in updated-for-CL form on the web at 
http://world.std.com/~pitman/Papers/Large-Systems.html

In our implementation we borrow kmp's overall PROCESS-OPTIONS and
concept to deal with creating component trees from defsystem surface
syntax.  [ this is not true right now, though it used to be and
probably will be again soon ]


* The Objects

** component

*** Component Attributes

**** A name (required)

This is a string or a symbol.  If a symbol, its name is taken and
lowercased.  The name must be a suitable value for the :name initarg
to make-pathname in whatever filesystem the system is to be found.

The lower-casing-symbols behaviour is unconventional, but was selected
after some consideration.  Observations suggest that the type of
systems we want to support either have lowercase as customary case
(Unix, Mac, windows) or silently convert lowercase to uppercase
(lpns), so this makes more sense than attempting to use :case :common,
which is reported not to work on some implementations

**** a version identifier (optional)

This is used by the test-system-version operation (see later).

**** *features* required

Traditionally defsystem users have used reader conditionals to include
or exclude specific per-implementation files.  This means that any
single implementation cannot read the entire system, which becomes a
problem if it doesn't wish to compile it, but instead for example to
create an archive file containing all the sources, as it will omit to
process the system-dependent sources for other systems.

Each component in an asdf system may therefore specify features using
the same syntax as #+ does, and it will (somehow) be ignored for
certain operations unless the feature conditional matches

**** dependencies on its siblings  (optional but often necessary)

There is an excitingly complicated relationship between the initarg
and the method that you use to ask about dependencies

Dependencies are between (operation component) pairs.  In your
initargs, you can say

:in-order-to ((compile-op (load-op "a" "b") (compile-op "c"))
	      (load-op (load-op "foo")))

- before performing compile-op on this component, we must perform
load-op on "a" and "b", and compile-op on c, - before performing
load-op, we have to load "foo"

The syntax is approximately

(this-op {(other-op required-components)}+)

required-components := component-name
                     | (required-components required-components)

component-name := string
                | (:version string minimum-version-object)

[ This is on a par with what ACL defsystem does.  mk-defsystem is less
general: it has an implied dependency

  for all x, (load x) depends on (compile x)

and using a :depends-on argument to say that b depends on a _actually_
means that

  (compile b) depends on (load a) 

This is insufficient for e.g. the McCLIM system, which requires that
all the files are loaded before any of them can be compiled ]

In asdf, the dependency information for a given component and
operation can be queried using (component-depends-on operation
component), which returns a list

((load-op "a") (load-op "b") (compile-op "c") ...)

component-depends-on can be subclassed for more specific
component/operation types: these need to (call-next-method) and append
the answer to their dependency, unless they have a good reason for
completely overriding the default dependencies

(If it weren't for CLISP, we'd be using a LIST method combination to
do this transparently.  But, we need to support CLISP.  If you have
the time for some CLISP hacking, I'm sure they'd welcome your fixes)

**** a pathname

This is optional and if absent will be inferred from name, type (the
subclass of source-file), and the location of parent.

The rules for this inference are:

(for source-files)
- the host is taken from the parent
- pathname type is (source-file-type component system)
- the pathname case option is :local
- the pathname is merged against the parent

(for modules)
- the host is taken from the parent
- the name and type are NIL
- the directory is (:relative component-name)
- the pathname case option is :local
- the pathname is merged against the parent

Note that the DEFSYSTEM operator (used to create a "top-level" system)
does additional processing to set the filesystem location of the
top component in that system.  This is detailed elsewhere

The answer to the frequently asked question "how do I create a system 
definition where all the source files have a .cl extension" is thus

(defmethod source-file-type ((c cl-source-file) (s (eql (find-system 'my-sys))))
   "cl")

**** properties (optional)

Packaging systems often require information about files or systems
additional to that specified here.  Programs that create vendor
packages out of asdf systems therefore have to create "placeholder"
information to satisfy these systems.  Sometimes the creator of an
asdf system may know the additional information and wish to provide it
directly.

(component-property component property-name) and associated setf method 
will allow the programmatic update of this information.  Property
names are compared as if by EQL, so use symbols or keywords or something

** Subclasses of component

*** 'source-file'

A source file is any file that the system does not know how to
generate from other components of the system. 

(Note that this is not necessarily the same thing as "a file
containing data that is typically fed to a compiler".  If a file is
generated by some pre-processor stage (e.g. a ".h" file from ".h.in"
by autoconf) then it is not, by this definition, a source file.
Conversely, we might have a graphic file that cannot be automatically
regenerated, or a proprietary shared library that we received as a
binary: these do count as source files for our purposes.  All
suggestions for better terminology gratefully received)

Subclasses of source-file exist for various languages.  

*** 'module', a collection of sub-components

This has extra slots for

 :components - the components contained in this module

 :default-component-class - for child components which don't specify
   their class explicitly

 :if-component-dep-fails takes one of the values :fail, :try-next, :ignore 
   (default value is :fail).  The other values can be used for implementing
   conditional compilation based on implementation *features*, where
   it is not necessary for all files in a module to be compiled

The default operation knows how to traverse a module, so most
operations will not need to provide methods specialised on modules.

The module may be subclassed to represent components such as
foreign-language linked libraries or archive files.

*** system, subclasses module

A system is a module with a few extra attributes for documentation
purposes.  In behaviour, it's usually identical.

Users can create new classes for their systems: the default defsystem
macro takes a :classs keyword argument.


** operation

An operation is instantiated whenever the user asks that an operation
be performed, inspected, or etc.  The operation object contains
whatever state is relevant to this purpose (perhaps a list of visited
nodes, for example) but primarily is a nice thing to specialise
operation methods on and easier than having them all be EQL methods.

There are no differences between standard operations and user-defined
operations, except that the user is respectfully requested to keep his
(or more importantly, our) package namespace clean

*** invoking operations

(operate operation system &rest keywords-args)

keyword-args are passed to the make-instance call when creating the
operation: valid keywords depend on the initargs that the operation is
defined to accept.  Note that dependencies may cause the operation to
invoke other operations on the system or its components: the new
operation will be created with the same initargs as the original one.

oos is accepted as a synonym for operate

*** standard operations

**** feature-dependent-op

This is not intended to be instantiated directly, but other operations
may inherit from it.  An instance of feature-dependent-op will ignore
any components which have a `features' attribute, unless the feature
combination it designates is satisfied by *features*

See the earlier explanation about the component features attribute for
more information

**** compile-op &key proclamations

If proclamations are supplied, they will be proclaimed.  This is a
good place to specify optimization settings

When creating a new component, you should provide methods for this.  

If you invoke compile-op as a user, component dependencies often mean
you may get some parts of the system loaded.  This may not necessarily
be the whole thing, though; for your own sanity it is recommended that
you use load-op if you want to load a system.

**** load-op &key proclamations

The default methods for load-op compile files before loading them.
For parity, your own methods on new component types should probably do
so too

**** load-source-op

This method will load the source for the files in a module even if the
source files have been compiled. Systems sometimes have knotty
dependencies which require that sources are loaded before they can be
compiled.  This is how you do that.

If you are creating a component type, you need to implement this
operation - at least, where meaningful.

**** test-system-version &key minimum

Asks the system whether it satisfies a version requirement.

The default method accepts a string, which is expected to contain of a
number of integers separated by #\. characters.  The method is not
recursive.  The component satisfies the version dependency if it has
the same major number as required and each of its sub-versions is
greater than or equal to the sub-version number required.

(defun version-satisfies (x y)
  (labels ((bigger (x y)
	     (cond ((not y) t)
		   ((not x) nil)
		   ((> (car x) (car y)) t)
		   ((= (car x) (car y))
		    (bigger (cdr x) (cdr y))))))
    (and (= (car x) (car y))
	 (or (not (cdr y)) (bigger (cdr x) (cdr y))))))

If that doesn't work for your system, you can override it.  I hope
yoyu have as much fun writing the new method as #lisp did
reimplementing this one. 

*** Creating new operations

subclass operation, provide methods for source-file for 

- output-files
- perform
   The perform method must call output-files to find out where to
   put its files, because the user is allowed to override output-files
   for local policy
- explain
- operation-done-p, if you don't like the default one

* Writing system definitions

** System designators

System designators are strings or symbols and behave just like
any other component names (including case conversion)

** find-system

Given a system designator, find-system finds an actual system - either
in memory, or in a file on the disk.  It funcalls each element in the
*system-definition-search-functions* list, expecting a pathname to be
returned.

If a suitable file exists, it is loaded if

- there is no system of that name in memory, 
- the file's last-modified time exceeds the last-modified time of the
  system in memory

When system definitions are loaded from .asd files, a new scratch
package is created for them to load into, so that different systems do
not overwrite each others operations.  The user may also wish to (and
is recommended to) include defpackage and in-package forms in his
system definition files, however, so that they can be loaded manually
if need be.  It is not recommended to use the CL-USER package for this
purpose, as definitions made in this package will affect the parsing
of asdf systems.

For convenience in the normal case, and for backward compatibility
with the spirit of mk-defsystem, the default contents of
*system-definition-search-functions* is a function called
sysdef-central-registry-search.  This looks in each of the directories
given by evaluating members of *central-registry*, for a file whose
name is the name of the system and whose type is "asd".  The first
such file is returned, whether or not it turns out to actually define
the appropriate system



** Syntax

Systems can always be constructed programmatically by instantiating
components using make-instance.  For most purposes, however, it is
likely that people will want a static defystem form. 

asdf is based around the principle that components should not have to
know defsystem syntax.  That is, the initargs that a component accepts
are not necessarily related to the defsystem form which creates it.

A defsystem parser must implement a `defsystem' macro, which can
be named for compatibility with whatever other system definition
utility is being emulated.  It should instantiate components in
accordance with whatever language it accepts, and register the topmost
component using REGISTER-SYSTEM

*** Native syntax

The native syntax is inspired by mk-defsystem, to the extent that it
should be possible to take most straightforward mk- system definitions
and run them with only light editing.  For my convenience, this turns
out to be basically the same as the initargs to the various
components, with a few extensions for convenience
               
system-definition := ( defsystem system-designator {option}* )

option := :components component-list
        | :pathname pathname
        | :default-component-class
        | :perform method-form 
        | :explain method-form
	| :output-files  method-form
        | :operation-done-p method-form
        | :depends-on ( {simple-component-name}* ) 
	| :serial [ t | nil ]
        | :in-order-to ( {dependency}+ )

component-list := ( {component-def}* )
                
component-def  := simple-component-name
                | ( component-type name {option}* )

component-type := :module | :file | :system | other-component-type

dependency := (dependent-op {requirement}+)
requirement := (required-op {required-component}+)
             | (feature feature-name)
dependent-op := operation-name
required-op := operation-name | feature

For example

(defsystem "foo"
  :version "1.0"
  :components ((:module "foo" :components ((:file "bar") (:file"baz") 
                                           (:file "quux"))
	        :perform (compile-op :after (op c)
			  (do-something c))
		:explain (compile-op :after (op c)
			  (explain-something c)))
               (:file "blah")))


The method-form tokens need explaining: esentially, 

	        :perform (compile-op :after (op c)
			  (do-something c))
		:explain (compile-op :after (op c)
			  (explain-something c)))
has the effect of

(defmethod perform :after ((op compile-op) (c (eql ...)))
	   (do-something c))
(defmethod explain :after ((op compile-op) (c (eql ...)))
	   (explain-something c))

where ... is the component in question; note that although this also
supports :before methods, they may not do what you want them to - a
:before method on perform ((op compile-op) (c (eql ...)))  will run
after all the dependencies and sub-components have been processed, but
before the component in question has been compiled.

**** Serial dependencies

If the `:serial t' option is specified for a module, asdf will add
dependencies for each each child component, on all the children
textually preceding it.  This is done as if by :depends-on

:components ((:file "a") (:file "b") (:file "c"))
:serial t

is equivalent to
:components ((:file "a") 
	     (:file "b" :depends-on ("a"))
	     (:file "c" :depends-on ("a" "b")))



have all the 

**** Source location

The :pathname option is optional in all cases for native-syntax
systems, and in the usual case the user is recommended not to supply
it.  If it is not supplied for the top-level form, defsystem will set
it from

- The host/device/directory parts of *load-truename*, if it is bound
- *default-pathname-defaults*, otherwise

If a system is being redefined, the top-level pathname will be 

- changed, if explicitly supplied or obtained from *load-truename*
- changed if it had previously been set from *default-pathname-defaults*
- left as before, if it had previously been set from *load-truename*
  and *load-truename* is not now bound

These rules are designed so that (i) find-system will load a system
from disk and have its pathname default to the right place, (ii)
this pathname information will not be overwritten with
*default-pathname-defaults* (which could be somewhere else altogether)
if the user loads up the .asd file into his editor and
interactively re-evaluates that form

 * Error handling

It is an error to define a system incorrectly: an implementation may
detect this and signal a generalised instance of
SYSTEM-DEFINITION-ERROR.

Operations may go wrong (for example when source files contain
errors).  These are signalled using generalised instances of
OPERATION-ERROR, with condition readers ERROR-COMPONENT and
ERROR-OPERATION for the component and operation which erred.

* Compilation error and warning handling

ASDF checks for warnings and errors when a file is compiled. The
variables *compile-file-warnings-behaviour* and
*compile-file-errors-behavior* controls the handling of any such
events. The valid values for these variables are :error, :warn, and
:ignore.

----------------------------------------------------------
                      TODO List
----------------------------------------------------------

* Outstanding spec questions, things to add

** packaging systems

*** manual page component?

** style guide for .asd files

You should either use keywords or be careful with the package that you
evaluate defsystem forms in.  Otherwise (defsystem partition ...)
being read in the cl-user package will intern a cl-user:partition
symbol, which will then collide with the partition:partition symbol.

Actually there's a hairier packages problem to think about too.
in-order-to is not a keyword: if you read defsystem forms in a package
that doesn't use ASDF, odd things might happen

** extending defsystem with new options

You might not want to write a whole parser, but just to add options to
the existing syntax.  Reinstate parse-option or something akin

** document all the error classes

** what to do with compile-file failure

Should check the primary return value from compile-file and see if
that gets us any closer to a sensible error handling strategy

** foreign files

lift unix-dso stuff from db-sockets

** Diagnostics

A "dry run" of an operation can be made with the following form:

(traverse (make-instance '<operation-name>)
          (find-system <system-name>)
          'explain)

This uses unexported symbols.  What would be a nice interface for this
functionality?

** patches

Sometimes one wants to 


* missing bits in implementation

** all of the above
** reuse the same scratch package whenever a system is reloaded from disk
** rules for system pathname defaulting are not yet implemented properly
** proclamations probably aren't
** when a system is reloaded with fewer components than it previously
   had, odd things happen

we should do something inventive when processing a defsystem form,
like take the list of kids and setf the slot to nil, then transfer
children from old to new list as they're found

**  traverse may become a normal function

If you're defining methods on traverse,  speak up.


** a lot of load-op methods can be rewritten to use input-files

so should be.


** (stuff that might happen later)

*** david lichteblau's patch for symlink resolution?

*** Propagation of the :force option.  ``I notice that

	(oos 'compile-op :araneida :force t)

also forces compilation of every other system the :araneida system
depends on.  This is rarely useful to me; usually, when I want to force
recompilation of something more than a single source file, I want to
recompile only one system.  So it would be more useful to have
make-sub-operation refuse to propagate ":force t" to other systems, and
propagate only something like ":force :recursively". ''

Ideally what we actually want is some kind of criterion that says
to which systems (and which operations) a :force switch will propagate.

The problem is perhaps that 'force' is a pretty meaningless concept.
How obvious is it that "load :force t" should force _compilation_?
But we don't really have the right dependency setup for the user to
compile :force t and expect it to work (files will not be loaded after
compilation, so the compile environment for subsequent files will be
emptier than it needs to be)

What does the user actually want to do when he forces?  Usually, for
me, update for use with a new version of the lisp compiler.  Perhaps
for recovery when he suspects that something has gone wrong.  Or else
when he's changed compilation options or configuration in some way
that's not reflected in the dependency graph.

Other possible interface: have a 'revert' function akin to 'make clean'

  (asdf:revert 'asdf:compile-op 'araneida) 

would delete any files produced by 'compile-op 'araneida.  Of course, it
wouldn't be able to do much about stuff in the image itself.

How would this work?

traverse

There's a difference between a module's dependencies (peers) and its
components (children).  Perhaps there's a similar difference in
operations?  For example, (load "use") depends-on (load "macros") is a
peer, whereas (load "use") depends-on (compile "use") is more of a
`subservient' relationship.
