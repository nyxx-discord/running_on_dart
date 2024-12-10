import {isLoggedIn} from "../service/auth";
import {Props} from "../constants";

export const ProtectedRoute = (props: Props) => {
    if (!isLoggedIn()) {
        return (
            <div>Not logged in</div>
        );
    }

    return <div children={props.children} />
};
