package jdk.nashorn.api.scripting;

import javax.script.ScriptEngine;
import javax.script.ScriptEngineFactory;
import java.util.List;

public final class NashornScriptEngineFactory implements ScriptEngineFactory {
    private final org.openjdk.nashorn.api.scripting.NashornScriptEngineFactory delegate =
            new org.openjdk.nashorn.api.scripting.NashornScriptEngineFactory();

    public String getEngineName() {
        return delegate.getEngineName();
    }

    public String getEngineVersion() {
        return delegate.getEngineVersion();
    }

    public List<String> getExtensions() {
        return delegate.getExtensions();
    }

    public List<String> getMimeTypes() {
        return delegate.getMimeTypes();
    }

    public List<String> getNames() {
        return delegate.getNames();
    }

    public String getLanguageName() {
        return delegate.getLanguageName();
    }

    public String getLanguageVersion() {
        return delegate.getLanguageVersion();
    }

    public Object getParameter(String key) {
        return delegate.getParameter(key);
    }

    public String getMethodCallSyntax(String object, String method, String... args) {
        return delegate.getMethodCallSyntax(object, method, args);
    }

    public String getOutputStatement(String toDisplay) {
        return delegate.getOutputStatement(toDisplay);
    }

    public String getProgram(String... statements) {
        return delegate.getProgram(statements);
    }

    public ScriptEngine getScriptEngine() {
        return delegate.getScriptEngine();
    }

    public ScriptEngine getScriptEngine(ClassFilter classFilter) {
        if (classFilter == null) {
            return delegate.getScriptEngine((org.openjdk.nashorn.api.scripting.ClassFilter) null);
        }

        return delegate.getScriptEngine(new org.openjdk.nashorn.api.scripting.ClassFilter() {
            public boolean exposeToScripts(String className) {
                return classFilter.exposeToScripts(className);
            }
        });
    }
}
