package com.edu.ug.server;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class Server {
  private static final Path clientFilePath = Paths.get("clientFile.txt");
  private static final Path serverFilePath = Paths.get("results.txt");
  private static final long CHECK_PERIOD_MS = 2500L;

  private static ScheduledExecutorService scheduler;
  private static volatile boolean running = false;

  private Server() {
    throw new UnsupportedOperationException("Server cannot be instantiated");
  }

  private static void notify(String message) {
    System.out.println(message);
  }

  public static synchronized void start() {
    if (isRunning()) throw new IllegalStateException("Server is already running");
    running = true;
    scheduler = Executors.newScheduledThreadPool(1);
    scheduler.scheduleWithFixedDelay(Server::job,
        CHECK_PERIOD_MS,
        CHECK_PERIOD_MS,
        TimeUnit.MILLISECONDS);
    notify("Server has been started with job...");
  }

  private static boolean existsClientFile() {
    return Files.exists(clientFilePath);
  }

  private static byte[] readFromClientFileBinaryData() {
    try {
      return Files.readAllBytes(clientFilePath);
    } catch (IOException e) {
      throw new RuntimeException(e);
    }
  }

  private static void writeToServerFileBinaryData(int num) {
    ByteBuffer resultBuffer = ByteBuffer.allocate(4).putInt(num);
    try {
      Files.write(serverFilePath, resultBuffer.array(),
          StandardOpenOption.CREATE,
          StandardOpenOption.WRITE,
          StandardOpenOption.TRUNCATE_EXISTING);
    } catch (IOException e) {
      throw new RuntimeException(e);
    }
  }

  private static void clearClientFile() {
    try {
      Files.write(clientFilePath, new byte[0],
          StandardOpenOption.WRITE,
          StandardOpenOption.TRUNCATE_EXISTING);
    } catch (IOException e) {
      throw new RuntimeException(e);
    }
  }

  private static void job() {
    try {
      if (!existsClientFile()) return;

      byte[] bytes = readFromClientFileBinaryData();
      if (bytes.length < 4) {
        notify("Server sees the clients file is empty. Stopping job for now...");
        return;
      }
      ByteBuffer buffer = ByteBuffer.wrap(bytes);

      writeToServerFileBinaryData(buffer.getInt() * 2);
      clearClientFile();

      notify("Server wrote result and cleared client file");
    } catch (Exception e) {
     notify("Error processing Server job: " + e.getMessage());
    }
  }

  public static synchronized void stop() {
    if (!isRunning()) return;
    running = false;
    if (scheduler != null) {
      scheduler.shutdownNow();
      scheduler = null;
    }
    notify("Shutting down the Server...");
  }

  public static boolean isRunning() {
    return running;
  }

}
