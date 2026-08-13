init expressjs typescript with swagger lib, with this project structure:
 +----------------+-------------------------------------------------+
 | -handler | Or controller |
 +----------------+-------------------------------------------------+
 | -subscriber | Treat like handler, dont put business logic here|
 +----------------+-------------------------------------------------+
 | -entities | |
 | |-dto | |
 | |-model | DB table mirror |
 | |-mapper | BuildErrReply, builder, etc |
 | |-constant | |
 +----------------+-------------------------------------------------+
 | -service | Core business logic |
 | |-impl | |
 +----------------+-------------------------------------------------+
 | -repository | |
 | |-impl | |
 +----------------+-------------------------------------------------+
 | -outbound | |
 | |-impl | |
 +----------------+-------------------------------------------------+
 | -provider | 3rd party sdk |
 | |-impl | |
 +----------------+-------------------------------------------------+
 | -utils | Or helpers, |
 +----------------+-------------------------------------------------+
 
 write those convention, guide as AGENTS.md development instruction, if you have other recommended best practice instruction, add them if needed