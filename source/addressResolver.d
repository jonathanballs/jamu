import ast;

class AddressResolver {

    Program program;

    this(Program program_) {
        program = program_;
    }

    Program resolveLabels() {
        uint[string] labels;
        // Step one get a list of all labels

        foreach(node; program.nodes) {
            if (node.type == typeid(Label)) {
            }
        }

        return Program();
    }
}

