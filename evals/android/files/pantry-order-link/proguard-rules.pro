# App-specific R8 rules. The libraries we use ship their own consumer rules.

# The 1.7.0-rc release build crashed opening an order from a link
# (SerializationException for OrderDetailDto). Keep the network models.
-keep class com.example.pantry.data.network.** { *; }
