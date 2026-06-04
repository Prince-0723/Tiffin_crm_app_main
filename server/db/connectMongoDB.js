import mongoose from "mongoose";
import config from "../config/index.js";

const connectMongoDB = async () => {
  try {
    const conn = await mongoose.connect(config.MONGODB_URL, {
      autoIndex: config.NODE_ENV !== "production",
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000,
    });

    console.log(`MongoDB connected => ${conn.connection.host}`);
  } catch (error) {
    console.error(`MongoDB connection error: ${error.message}`);
    process.exit(1);
  }
};

mongoose.connection.on("disconnected", () => {
  console.warn("MongoDB disconnected");
});

export default connectMongoDB;
