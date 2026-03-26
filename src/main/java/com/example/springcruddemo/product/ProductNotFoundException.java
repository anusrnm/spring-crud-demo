package com.example.springcruddemo.product;

public class ProductNotFoundException extends RuntimeException {

    public ProductNotFoundException(Long id) {
        super("Product with id %d was not found".formatted(id));
    }
}
