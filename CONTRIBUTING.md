# Contributing Guide

dart\_amqp is of course Open Source! Feel free to contribute!

## Getting Started

- Make sure you have a [GitHub Account](https://github.com/signup/free).
- Make sure the [Dart SDK](https://www.dartlang.org/tools/sdk/) is installed on your system.
- Make sure you have [Git](http://git-scm.com/) installed on your system.
- [Fork](https://help.github.com/articles/fork-a-repo) the [repository](https://github.com/achilleasa/dart_amqp) on GitHub.

## Making Changes

 - [Create a branch](https://help.github.com/articles/creating-and-deleting-branches-within-your-repository) for your changes.
 - [Commit your code](http://git-scm.com/book/en/Git-Basics-Recording-Changes-to-the-Repository) for each logical change (see [tips for creating better commit messages](http://robots.thoughtbot.com/5-useful-tips-for-a-better-commit-message)).
 - [Push your change](https://help.github.com/articles/pushing-to-a-remote) to your fork.
 - [Create a Pull Request](https://help.github.com/articles/creating-a-pull-request) on GitHub for your change.

## Code Style

When submitting pull requests try to follow the [Dart Style Guide](https://www.dartlang.org/articles/style-guide/).

## Unit tests

Please make sure you submit a unit-test together with your pull request. All unit tests should be placed inside the ```test/lib``` folder. You can add you own unit-tests to the existing test suites or create a new one. If you need to create a new test suite for your PR then make sure you also update the main test runner which is located at ```tests/run_all.dart```.

The project ships with a the ```test/test_coverage.sh``` script for generating html code coverage reports using [dart-lang/coverage](https://github.com/dart-lang/coverage) and LCOV.