# Arqivarius

This is a Ruby port of [arq_restore][].

## Installation

Clone the rebo, `bundle`, and run from within:

    $ bundle exec bin/arqivarius

## Usage

You have to specify your AWS credentials as well as backup encription password
in environment variables.

* **ARQ_ACCESS_KEY** — Your AWS access key
* **ARQ_SECRET_KEY** — Your AWS secred key
* **ARQ_ENCRYPTION_PASSWORD** — Your backup encryption password

## Motivation

Arq is a great piece of software. It is intuitive for the user and roubust
underneath. Despite that it gave me hard time in the most critical of times —
when I need to restore a huge backup (from Glacier).

Original [arq_restore][] has problems of its own. For example it chokes if there
are a few bakup sets with different encryption passwords under one AWS account,
etc.

I'm not very good with Objective-C so I decided to rewrite it in Ruby. The goal
is not to have bulletproof code but rather the one that will get my files out of
Glacier (eventually).

## Is it any good?

No. Well, maybe. Right now it can has all the basic functionality of
`arq_restore`. It can list backup sets and reflog. It also can restore backups
from S3.

## Contributing

1. Fork it ( http://github.com/<my-github-username>/arqivarius/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

I don't know. Honestly.

It might be MIT but I'm not sure how that corresponds with the [original
license](https://github.com/sreitshamer/arq_restore/#license).



[arq_restore]: https://github.com/sreitshamer/arq_restore/
