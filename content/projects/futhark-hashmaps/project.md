A hash map is a data structure which stores a set of keys where each key maps to a given value. We have implemented static, data-parallel hash maps in [Futhark](https://futhark-lang.org/), meaning that the set of keys are fixed at a given hash map's conception and these hash maps can be constructed in parallel.

These hash maps use the Fredman et al. construction due to it being well suited for functional array languages. The goal of the project will be to create a hash map which is dynamic such that more keys can be inserted.

We believe a good idea for this project is to use a combination of perfect hashing and open addressing.
