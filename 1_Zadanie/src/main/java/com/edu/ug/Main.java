package com.edu.ug;

import com.edu.ug.client.Client;
import com.edu.ug.server.Server;

public class Main {

  private static void runClient() {
    try (Client client = new Client()) {
      client.getNextInt();
      client.writeToClientFileBinaryData();

      Thread.sleep(5000);

      int result = client.readFromServerFileInt();
      System.out.println("Success!!! Client has gotten the result: " + result);
    } catch (Exception e) {
      e.printStackTrace();
    }
  }

  public static void main(String[] args) {
    Server.start();
    runClient();
    runClient();
    Server.stop();
  }
}