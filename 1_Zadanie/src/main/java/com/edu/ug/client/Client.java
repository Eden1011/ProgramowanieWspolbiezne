package com.edu.ug.client;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.InputMismatchException;
import java.util.Scanner;

public class Client implements AutoCloseable {
  private Scanner scanner = new Scanner(System.in);
  private static final Path clientFilePath = Paths.get("clientFile.txt");
  private static final Path serverFilePath = Paths.get("results.txt");
  private int num;
  private boolean closed = false;

  public Client() {}

  private static void notify(String message) {
    System.out.println(message);
  }

  private void checkClosed() {
    if (closed) throw new IllegalStateException("Client has been closed and cannot be used");
  }

  public int getNextInt() throws InputMismatchException {
    checkClosed();
    notify("Client asks politely for the next int:... > ");
    num = scanner.nextInt();
    return num;
  }

  public void writeToClientFileBinaryData() throws IOException {
    checkClosed();
    ByteBuffer buffer = ByteBuffer.allocate(4).putInt(num);
    Files.write(clientFilePath, buffer.array(), StandardOpenOption.CREATE, StandardOpenOption.WRITE, StandardOpenOption.TRUNCATE_EXISTING);
  }

  public int readFromServerFileInt() throws IOException {
    checkClosed();
    byte[] bytes = Files.readAllBytes(serverFilePath);
    ByteBuffer buffer = ByteBuffer.wrap(bytes);
    return buffer.getInt();
  }

  @Override
  public void close() throws IOException {
    if (closed) {
      return;
    }
    closed = true;
    scanner = null;
  }

}
