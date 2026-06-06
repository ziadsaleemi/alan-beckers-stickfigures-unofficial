package jdk.nashorn.api.scripting;

public interface ClassFilter {
    boolean exposeToScripts(String className);
}
