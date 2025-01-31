import {isLoggedIn} from "../service/auth";
import {DefaultAppProps} from "../constants";

export const ProtectedRoute = (props: DefaultAppProps) => {
    if (!isLoggedIn()) {
        return (
            <div>Not logged in</div>
        );
    }

    return <div>{props.children}</div>;
};
