package ovh.testdomain.project;

import io.javalin.Javalin;
import io.javalin.core.util.JavalinBindException;

public class Main {
    private static final int PORT_PRIMARY = 8000;
    private static final int PORT_SECONDARY = 8001;

    public static void main(String[] args) {
        Javalin app;
        try {
            app = Javalin.create().start(PORT_PRIMARY);
        } catch (JavalinBindException e) {
            app = Javalin.create().start(PORT_SECONDARY);
        }

        app.get("/", ctx -> ctx.result("Version " + Main.class.getPackage().getImplementationVersion()));
    }
}
